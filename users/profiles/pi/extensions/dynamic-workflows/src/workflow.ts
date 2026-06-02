import { createHash } from "node:crypto";
import vm from "node:vm";
// acorn is vendored locally (the extension's only non-peer dependency) as a
// self-contained ESM bundle; see ../vendor/acorn.mjs and ../vendor/ACORN-LICENSE.
// @ts-ignore - the vendored .mjs ships no type declarations.
import { parse } from "../vendor/acorn.mjs";
// Structural stand-in for acorn's Node type (we only read type/start/end and
// walk child nodes), since the vendored bundle carries no types.
type Node = { type: string; start: number; end: number };
import type { TSchema } from "typebox";
import type { AgentUsage } from "./agent.ts";
import { WorkflowAgent, type WorkflowAgentOptions } from "./agent.ts";
import {
  DEFAULT_AGENT_TIMEOUT_MS,
  DEFAULT_TOKEN_BUDGET,
  MAX_AGENTS_PER_RUN,
  MAX_CONCURRENCY,
  WORKFLOW_SYNC_TIMEOUT_MS,
} from "./config.ts";
import { WorkflowError, WorkflowErrorCode, wrapError } from "./errors.ts";
import { createWorkflowLogger } from "./logger.ts";
import { parseModelRoutingFromMeta, resolveModelForPhase } from "./model-routing.ts";
import { createWorktree, removeWorktree, type Worktree } from "./worktree.ts";

export interface WorkflowMetaPhase {
  title: string;
  detail?: string;
  model?: string;
}

export interface WorkflowMeta {
  name: string;
  description: string;
  whenToUse?: string;
  phases?: WorkflowMetaPhase[];
}

/** One cached agent() result, keyed by its deterministic call index. */
export interface JournalEntry {
  index: number;
  /** sha256 of the call's identity (prompt + model + phase + agentType + schema). */
  hash: string;
  result: unknown;
}

/**
 * Global resources shared across a run and any workflow() nested inside it, so
 * the 6-concurrent / 1000-total caps and the token budget hold across nesting
 * instead of each level getting its own limiter and counters.
 */
export interface SharedRuntime {
  limiter: <T>(fn: () => Promise<T>) => Promise<T>;
  agentCount: number;
  spent: number;
  tokenUsage: { input: number; output: number; total: number; cost: number };
  depth: number;
  /** Real subagent runs started (excludes cached resume replays). */
  agentsAttempted: number;
  /** Of those, how many failed and were degraded to a null result. */
  agentsFailed: number;
}

export interface WorkflowRunOptions extends WorkflowAgentOptions {
  args?: unknown;
  agent?: Pick<WorkflowAgent, "run">;
  /** The session's main model (provider/id), shown in /workflows for default agents. */
  mainModel?: string;
  concurrency?: number;
  tokenBudget?: number | null;
  signal?: AbortSignal;
  /** Maximum number of agents allowed in this run. Default: 1000 */
  maxAgents?: number;
  /** Timeout per agent in milliseconds. Default: 5 minutes */
  agentTimeoutMs?: number;
  /** Whether to persist logs to disk. Default: true */
  persistLogs?: boolean;
  /** Run ID for persistence. Auto-generated if not provided. */
  runId?: string;
  /** Resume: cached agent results keyed by deterministic call index. */
  resumeJournal?: Map<number, JournalEntry>;
  /** Resume: the run being resumed (informational; enables resume mode). */
  resumeFromRunId?: string;
  /** Called after each live agent completes so the caller can persist the journal. */
  onAgentJournal?: (entry: JournalEntry) => void;
  /** Internal: shared runtime inherited by a nested workflow() call. */
  sharedRuntime?: SharedRuntime;
  /** Resolve a saved-workflow name to its script, enabling `workflow('name', args)`. */
  loadSavedWorkflow?: (name: string) => string | undefined;
  onLog?: (message: string) => void;
  onPhase?: (title: string) => void;
  onAgentStart?: (event: { label: string; phase?: string; prompt: string; model?: string }) => void;
  onAgentEnd?: (event: {
    label: string;
    phase?: string;
    result: unknown;
    tokens?: number;
    worktree?: string;
    model?: string;
  }) => void;
  onTokenUsage?: (usage: { input: number; output: number; total: number; cost: number }) => void;
}

export interface WorkflowRunResult<T = unknown> {
  meta: WorkflowMeta;
  result: T;
  logs: string[];
  phases: string[];
  agentCount: number;
  durationMs: number;
  runId?: string;
  tokenUsage?: {
    input: number;
    output: number;
    total: number;
    cost: number;
  };
}

export interface AgentOptions<TSchemaDef extends TSchema | undefined = TSchema | undefined> {
  label?: string;
  phase?: string;
  schema?: TSchemaDef;
  /**
   * Run this agent on a specific model (`provider/modelId` or a bare `modelId`).
   * The workflow author chooses per-agent models per the routing policy in the
   * tool guidelines (e.g. a lighter model for exploration, the main model for
   * analysis). When omitted, the session's main model is used.
   */
  model?: string;
  isolation?: "worktree";
  agentType?: string;
  /** Override timeout for this specific agent. */
  timeoutMs?: number;
}

interface RuntimeState {
  currentPhase?: string;
  logs: string[];
  phases: string[];
  /** Monotonic, assigned at lexical agent() call time — the stable resume key. */
  callSeq: number;
}

type AnyNode = Node & { [key: string]: any; start: number; end: number };

/**
 * A `Math` without `random`, handed to the workflow vm context. The static
 * determinism guard (assertDeterministic) already rejects `Math.random` and
 * references to Date/globalThis/Reflect/Function/eval, but it can't see an alias
 * like `const M = Math; M.random()`. Removing `random` from the live binding
 * closes that residual at runtime. Native Math methods don't use `this`, so the
 * copied references work; the constants (PI, E, …) copy by value.
 */
const SAFE_MATH: typeof Math = Object.freeze(
  Object.fromEntries(
    Object.getOwnPropertyNames(Math)
      .filter((key) => key !== "random")
      .map((key) => [key, (Math as unknown as Record<string, unknown>)[key]]),
  ),
) as unknown as typeof Math;

export async function runWorkflow<T = unknown>(
  script: string,
  options: WorkflowRunOptions = {},
): Promise<WorkflowRunResult<T>> {
  const started = Date.now();
  const { meta, body } = parseWorkflowScript(script);
  // Per-phase model routing from meta.phases[].model (empty when none declared).
  const routingConfig = parseModelRoutingFromMeta(meta.phases);
  const maxAgents = options.maxAgents ?? MAX_AGENTS_PER_RUN;
  const agentTimeoutMs = options.agentTimeoutMs ?? DEFAULT_AGENT_TIMEOUT_MS;
  const runId = options.runId ?? `run-${started.toString(36)}`;
  const baseCwd = options.cwd ?? process.cwd();

  // Internal abort, linked to (but distinct from) the external/user signal. We
  // abort it ourselves when a non-recoverable error (agent-cap / token-budget)
  // bubbles out of parallel()/pipeline(), so in-flight sibling subagents stop
  // instead of running on detached. Kept separate from options.signal so the
  // manager still distinguishes a real failure (this) from a user abort.
  const runAbort = new AbortController();
  const onExternalAbort = () => runAbort.abort();
  if (options.signal) {
    if (options.signal.aborted) runAbort.abort();
    else options.signal.addEventListener("abort", onExternalAbort, { once: true });
  }

  // Initialize logger
  const logger = createWorkflowLogger({
    runId,
    cwd: options.cwd ?? process.cwd(),
    persist: options.persistLogs ?? true,
    onLog: options.onLog,
  });

  const state: RuntimeState = {
    logs: [],
    phases: [],
    callSeq: 0,
  };

  const agentRunner = options.agent ?? new WorkflowAgent(options);
  const concurrency = Math.max(
    1,
    Math.min(options.concurrency ?? Math.max(1, (globalThis.navigator?.hardwareConcurrency ?? 8) - 2), MAX_CONCURRENCY),
  );
  // Global caps + budget are shared with any nested workflow() so they hold across nesting.
  const isOutermost = !options.sharedRuntime;
  const shared: SharedRuntime = options.sharedRuntime ?? {
    limiter: createLimiter(concurrency),
    agentCount: 0,
    spent: 0,
    tokenUsage: { input: 0, output: 0, total: 0, cost: 0 },
    depth: 0,
    agentsAttempted: 0,
    agentsFailed: 0,
  };
  const limiter = shared.limiter;

  const log = (message: string) => {
    const text = String(message);
    state.logs.push(text);
    logger.log(text);
  };

  const phase = (title: string) => {
    state.currentPhase = title;
    if (!state.phases.includes(title)) state.phases.push(title);
    options.onPhase?.(title);
  };

  const tokenBudget = options.tokenBudget ?? DEFAULT_TOKEN_BUDGET;
  const budget = Object.freeze({
    total: tokenBudget,
    spent: () => shared.spent,
    remaining: () => (tokenBudget == null ? Infinity : Math.max(0, tokenBudget - shared.spent)),
  });

  const throwIfAborted = () => {
    if (runAbort.signal.aborted) {
      throw new WorkflowError("workflow aborted", WorkflowErrorCode.WORKFLOW_ABORTED, { recoverable: true });
    }
  };

  const agent = async (prompt: string, agentOptions: AgentOptions = {}) => {
    throwIfAborted();

    // Check agent limit
    if (shared.agentCount >= maxAgents) {
      throw new WorkflowError(
        `Agent limit exceeded (${maxAgents}). Use maxAgents option to increase the limit.`,
        WorkflowErrorCode.AGENT_LIMIT_EXCEEDED,
        { recoverable: false },
      );
    }

    if (budget.total !== null && budget.remaining() <= 0) {
      throw new WorkflowError("workflow token budget exhausted", WorkflowErrorCode.TOKEN_BUDGET_EXHAUSTED, {
        recoverable: false,
      });
    }

    // Reserve the slot synchronously, before the limiter, so a wide
    // parallel()/pipeline() fan-out can't enqueue more than maxAgents before any
    // of them start (the cap is a per-run lifetime cap, not a concurrency cap).
    const agentNumber = ++shared.agentCount;

    const assignedPhase = agentOptions.phase ?? state.currentPhase;
    const requestedLabel = agentOptions.label?.trim();
    // Precedence: explicit agentOptions.model > phase model (meta.phases[].model).
    const modelSpec = agentOptions.model ?? resolveModelForPhase(assignedPhase, routingConfig);
    // For display in /workflows: the model this agent runs on — its explicit/phase
    // spec, else the session's main model. The real resolved id overrides this via
    // onModelResolved once the subagent session is created.
    let displayModel = modelSpec ?? options.mainModel;

    // Deterministic resume key: assigned at lexical call time, before the limiter,
    // so parallel()/pipeline() fan-out is reproducible for a fixed script.
    const callIndex = state.callSeq++;
    const callHash = hashAgentCall(prompt, modelSpec, assignedPhase, agentOptions);

    // Resume: replay a cached result for an unchanged call (matching hash), without
    // consuming a concurrency slot, tokens, or a real subagent run.
    const cached = options.resumeJournal?.get(callIndex);
    if (cached && cached.hash === callHash) {
      const label = requestedLabel || defaultAgentLabel(assignedPhase, agentNumber);
      options.onAgentStart?.({ label, phase: assignedPhase, prompt, model: displayModel });
      options.onAgentEnd?.({ label, phase: assignedPhase, result: cached.result, tokens: 0, model: displayModel });
      return cached.result;
    }

    return limiter(async () => {
      const label = requestedLabel || defaultAgentLabel(assignedPhase, agentNumber);
      const timeout = agentOptions.timeoutMs ?? agentTimeoutMs;
      // A real subagent run (cached resume replays returned earlier, above).
      shared.agentsAttempted++;

      options.onAgentStart?.({ label, phase: assignedPhase, prompt, model: displayModel });

      // Optional per-agent worktree isolation (deterministic name -> stable resume keys).
      let worktree: Worktree | undefined;
      if (agentOptions.isolation === "worktree") {
        worktree = await createWorktree(baseCwd, `${runId}-${callIndex}-${label}`);
        if (!worktree.isolated) log(`isolation ignored for "${label}" (${worktree.reason})`);
      }
      const runCwd = worktree?.isolated ? worktree.cwd : undefined;

      // Captured from the subagent's real session usage; falls back to an
      // estimate when the provider reports no usage (total === 0).
      let usage: AgentUsage | undefined;
      const recordTokens = (result: unknown): number => {
        const tokens = usage && usage.total > 0 ? usage.total : estimateTokens(result) + estimateTokens(prompt);
        if (usage) {
          shared.tokenUsage.input += usage.input;
          shared.tokenUsage.output += usage.output;
          shared.tokenUsage.cost += usage.cost;
        }
        shared.tokenUsage.total += tokens;
        shared.spent += tokens;
        return tokens;
      };

      // Per-agent timeout that actually aborts the subagent: a controller linked
      // to the workflow signal, aborted on timeout. agent.ts wires the signal to
      // session.abort(), so the subagent stops instead of being orphaned by a
      // bare Promise.race — and because we await the real run promise (it settles
      // after the abort), the worktree teardown below runs only once it's gone.
      const agentController = new AbortController();
      let timedOut = false;
      const onParentAbort = () => agentController.abort();
      // Link to the run's internal signal so BOTH a user abort and an internal
      // non-recoverable-error abort stop this subagent.
      if (runAbort.signal.aborted) agentController.abort();
      else runAbort.signal.addEventListener("abort", onParentAbort, { once: true });
      const timeoutTimer = setTimeout(() => {
        timedOut = true;
        agentController.abort();
      }, timeout);
      const timeoutError = () =>
        new WorkflowError(`Agent "${label}" timed out after ${timeout}ms`, WorkflowErrorCode.AGENT_TIMEOUT, {
          recoverable: true,
        });

      try {
        throwIfAborted();

        const result = await agentRunner.run(prompt, {
          label,
          schema: agentOptions.schema,
          signal: agentController.signal,
          instructions: buildAgentInstructions(assignedPhase, agentOptions),
          model: modelSpec,
          cwd: runCwd,
          onModelResolved: (id: string) => {
            displayModel = id;
          },
          onUsage: (u: AgentUsage) => {
            usage = u;
          },
        } as any);

        if (timedOut) throw timeoutError();
        throwIfAborted();

        const tokens = recordTokens(result);
        options.onAgentJournal?.({ index: callIndex, hash: callHash, result });
        options.onAgentEnd?.({ label, phase: assignedPhase, result, tokens, worktree: runCwd, model: displayModel });
        return result;
      } catch (error) {
        // A timeout aborts agentController, so the run rejects with an abort
        // error; classify that as a (recoverable) timeout rather than an abort.
        const workflowError = timedOut ? timeoutError() : wrapError(error, { agentLabel: label });
        if (!timedOut && options.signal?.aborted) throw error;

        logger.error(`agent ${label} failed: ${workflowError.message}`);
        const tokens = recordTokens(null);
        options.onAgentEnd?.({ label, phase: assignedPhase, result: null, tokens, worktree: runCwd });

        // Return null for recoverable errors
        if (workflowError.recoverable) {
          shared.agentsFailed++;
          return null;
        }
        throw workflowError;
      } finally {
        clearTimeout(timeoutTimer);
        runAbort.signal.removeEventListener("abort", onParentAbort);
        // Always tear down the worktree, even on timeout/abort.
        if (worktree?.isolated) await removeWorktree(worktree);
      }
    });
  };

  const parallel = async (thunks: Array<() => Promise<unknown>>) => {
    throwIfAborted();
    if (!Array.isArray(thunks)) throw new TypeError("parallel() expects an array of functions");
    if (thunks.some((thunk) => typeof thunk !== "function")) {
      throw new TypeError("parallel() expects an array of functions, not promises. Wrap each call: () => agent(...)");
    }
    return Promise.all(
      thunks.map(async (thunk, index) => {
        try {
          return await thunk();
        } catch (error) {
          if (options.signal?.aborted) throw error;
          const workflowError = wrapError(error);
          // Cap/budget errors are non-recoverable: abort the fan-out (stopping
          // in-flight siblings) instead of silently degrading them to null.
          if (!workflowError.recoverable) {
            runAbort.abort();
            throw workflowError;
          }
          log(`parallel[${index}] failed: ${workflowError.message}`);
          return null;
        }
      }),
    );
  };

  const pipeline = async (
    items: unknown[],
    ...stages: Array<(prev: unknown, original: unknown, index: number) => unknown>
  ) => {
    throwIfAborted();
    if (!Array.isArray(items)) throw new TypeError("pipeline() expects an array as the first argument");
    if (stages.some((stage) => typeof stage !== "function")) {
      throw new TypeError("pipeline() stages must be functions: pipeline(items, item => ..., result => ...)");
    }
    return Promise.all(
      items.map(async (item, index) => {
        let value: unknown = item;
        for (const stage of stages) {
          try {
            throwIfAborted();
            value = await stage(value, item, index);
            throwIfAborted();
          } catch (error) {
            if (options.signal?.aborted) throw error;
            const workflowError = wrapError(error);
            // Cap/budget errors are non-recoverable: abort the pipeline (stopping
            // in-flight siblings) instead of silently degrading them to null.
            if (!workflowError.recoverable) {
              runAbort.abort();
              throw workflowError;
            }
            log(`pipeline[${index}] failed: ${workflowError.message}`);
            return null;
          }
        }
        return value;
      }),
    );
  };

  // Nested workflow(): run a saved workflow (or a raw script) inline, sharing this
  // run's limiter/counters/budget so the global caps hold. One level deep only.
  const workflowFn = async (nameOrScript: string, childArgs?: unknown) => {
    throwIfAborted();
    if (shared.depth >= 1) {
      throw new WorkflowError("workflow() can nest only one level deep", WorkflowErrorCode.SCRIPT_VALIDATION_ERROR, {
        recoverable: false,
      });
    }
    const resolved = options.loadSavedWorkflow?.(String(nameOrScript));
    const childScript = resolved ?? String(nameOrScript);
    shared.depth++;
    try {
      const child = await runWorkflow(childScript, {
        ...options,
        args: childArgs,
        sharedRuntime: shared,
        // A nested run is its own script; never reuse the parent's resume journal.
        resumeJournal: undefined,
        resumeFromRunId: undefined,
        runId: `${runId}-nested${shared.depth}`,
        persistLogs: false,
      });
      return child.result;
    } finally {
      shared.depth--;
    }
  };

  const context = vm.createContext({
    agent,
    parallel,
    pipeline,
    workflow: workflowFn,
    log,
    phase,
    args: options.args,
    cwd: options.cwd ?? process.cwd(),
    process: Object.freeze({ cwd: () => options.cwd ?? process.cwd() }),
    budget,
    console: {
      log,
      info: log,
      warn: (m: unknown) => log(`[warn] ${String(m)}`),
      error: (m: unknown) => log(`[error] ${String(m)}`),
    },
    JSON,
    // Math without `random` (see SAFE_MATH) — defense-in-depth for aliased forms.
    Math: SAFE_MATH,
    Array,
    Object,
    String,
    Number,
    Boolean,
    Set,
    Map,
    Promise,
  });

  const wrapped = `(async () => {\n${body}\n})()`;
  let result: unknown;
  try {
    // The `vm` timeout bounds SYNCHRONOUS evaluation — the script's sync prefix
    // up to its first await — which is exactly the freeze case (a sync infinite
    // loop before any await blocks the TUI). Async orchestration is unbounded.
    result = await new vm.Script(wrapped, { filename: `${meta.name || "workflow"}.js` }).runInContext(context, {
      timeout: WORKFLOW_SYNC_TIMEOUT_MS,
    });
  } catch (error) {
    if (error instanceof Error && /timed out/i.test(error.message)) {
      throw new WorkflowError(
        `workflow script exceeded ${WORKFLOW_SYNC_TIMEOUT_MS}ms of synchronous execution (likely an infinite loop before the first await)`,
        WorkflowErrorCode.SCRIPT_VALIDATION_ERROR,
        { recoverable: false },
      );
    }
    throw error;
  } finally {
    options.signal?.removeEventListener("abort", onExternalAbort);
  }

  // Every subagent failed: each agent() degraded to null, so the script likely
  // "succeeded" with all-null results. Surface that loudly instead of letting an
  // empty success slip into the conversation. Only the outermost run reports, so
  // a fully-failed nested workflow isn't double-counted.
  if (isOutermost && shared.agentsAttempted > 0 && shared.agentsFailed >= shared.agentsAttempted) {
    log(
      `⚠️ all ${shared.agentsAttempted} agent run(s) failed — results are empty/null. ` +
        `Check the run log; the workflow did not produce real output.`,
    );
  }

  // Persist logs
  const logFile = logger.persist();
  if (logFile) {
    log(`Logs persisted to ${logFile}`);
  }

  // Emit final token usage
  options.onTokenUsage?.(shared.tokenUsage);

  return {
    meta,
    result: result as T,
    logs: state.logs,
    phases: state.phases,
    agentCount: shared.agentCount,
    durationMs: Date.now() - started,
    runId,
    tokenUsage: shared.tokenUsage,
  };
}

export function parseWorkflowScript(script: string): { meta: WorkflowMeta; body: string } {
  const ast = parse(script, {
    ecmaVersion: "latest",
    sourceType: "module",
    allowAwaitOutsideFunction: true,
    allowReturnOutsideFunction: true,
    ranges: false,
  }) as AnyNode;

  // Determinism is enforced on the AST (not a raw-source regex), so the tokens
  // are only rejected as real calls — never inside strings or comments — and
  // `Date['now']()`-style bypasses are still caught.
  assertDeterministic(ast);

  const first = ast.body?.[0] as AnyNode | undefined;
  if (first?.type !== "ExportNamedDeclaration") {
    throw new WorkflowError(
      "`export const meta = { name, description, phases }` must be the first statement in the script",
      WorkflowErrorCode.SCRIPT_VALIDATION_ERROR,
      { recoverable: false },
    );
  }

  const declaration = first.declaration as AnyNode | null;
  if (declaration?.type !== "VariableDeclaration" || declaration.kind !== "const") {
    throw new WorkflowError(
      "meta export must be `export const meta = ...`",
      WorkflowErrorCode.SCRIPT_VALIDATION_ERROR,
      {
        recoverable: false,
      },
    );
  }
  if (declaration.declarations.length !== 1) {
    throw new WorkflowError("meta export must declare only `meta`", WorkflowErrorCode.SCRIPT_VALIDATION_ERROR, {
      recoverable: false,
    });
  }

  const declarator = declaration.declarations[0] as AnyNode;
  if (declarator.id?.type !== "Identifier" || declarator.id.name !== "meta") {
    throw new WorkflowError("meta export must declare `meta`", WorkflowErrorCode.SCRIPT_VALIDATION_ERROR, {
      recoverable: false,
    });
  }
  if (!declarator.init)
    throw new WorkflowError("meta must have a literal value", WorkflowErrorCode.SCRIPT_VALIDATION_ERROR, {
      recoverable: false,
    });

  const meta = evaluateLiteral(declarator.init, "meta");
  validateMeta(meta);

  return {
    meta,
    body: script.slice(0, first.start) + script.slice(first.end),
  };
}

/**
 * Depth-first walk over an acorn AST, visiting every child node with its parent
 * and the parent key (role) under which it sits — so a visitor can tell, e.g., a
 * value reference to `Date` from the `.Date` of a member access or a `{Date:…}` key.
 */
function walkAst(
  node: AnyNode | null | undefined,
  parent: AnyNode | null,
  role: string | null,
  visit: (n: AnyNode, parent: AnyNode | null, role: string | null) => void,
): void {
  if (!node || typeof node !== "object" || typeof node.type !== "string") return;
  visit(node, parent, role);
  for (const key of Object.keys(node)) {
    const value = (node as Record<string, unknown>)[key];
    if (Array.isArray(value)) {
      for (const child of value) walkAst(child as AnyNode, node, key, visit);
    } else if (value && typeof value === "object") {
      walkAst(value as AnyNode, node, key, visit);
    }
  }
}

/** Static property name of a MemberExpression — `obj.prop` or `obj['prop']`, else undefined. */
function memberPropName(node: AnyNode): string | undefined {
  const prop = node.property as AnyNode;
  if (!node.computed && prop?.type === "Identifier") return prop.name;
  if (node.computed && prop?.type === "Literal" && typeof prop.value === "string") return prop.value;
  return undefined;
}

/**
 * True when an Identifier node is a *value reference* (a read of the binding),
 * not a property name (`x.Date`), an object-literal key (`{Date:…}`), or a
 * binding site (`const Date = …`, a function parameter/name). Used to flag uses
 * of forbidden globals while ignoring harmless same-named properties/keys.
 */
function isValueReference(parent: AnyNode | null, role: string | null): boolean {
  if (!parent) return true;
  if (parent.type === "MemberExpression" && role === "property" && !parent.computed) return false;
  if (parent.type === "Property" && role === "key" && !parent.computed) return false;
  if (parent.type === "VariableDeclarator" && role === "id") return false;
  if (
    (parent.type === "FunctionDeclaration" ||
      parent.type === "FunctionExpression" ||
      parent.type === "ArrowFunctionExpression") &&
    (role === "id" || role === "params")
  ) {
    return false;
  }
  if (parent.type === "CatchClause" && role === "param") return false;
  return true;
}

/**
 * Non-deterministic globals that have no legitimate use in a deterministic
 * workflow script. Forbidding any *value reference* to them (not just `Date.now`)
 * also catches member-chained and aliased forms — `globalThis.Date.now()`,
 * `const D = Date; D.now()`, `Reflect.get(Date,'now')()`, `Function('return Date')()`.
 * `Math` is intentionally absent: it's needed for `Math.floor` etc.; only
 * `Math.random` is rejected, by property name below.
 */
const FORBIDDEN_GLOBALS = new Set(["Date", "globalThis", "Reflect", "Function", "eval"]);

/** Reject the non-deterministic builtins (Date / Math.random / globalThis / …) via the AST. */
function assertDeterministic(ast: AnyNode): void {
  const reject = (what: string): never => {
    throw new WorkflowError(
      `Workflow scripts must be deterministic: ${what} is not available ` +
        "(Date.now()/Math.random()/new Date() — including globalThis/alias forms — are rejected)",
      WorkflowErrorCode.SCRIPT_VALIDATION_ERROR,
      { recoverable: false },
    );
  };
  walkAst(ast, null, null, (n, parent, role) => {
    if (n.type === "MemberExpression") {
      // Math.random / Math['random'] (Math itself stays available for Math.floor etc.).
      if (n.object?.type === "Identifier" && n.object.name === "Math" && memberPropName(n) === "random") {
        reject("Math.random");
      }
      // Prototype/constructor reach-arounds. The context is seeded with host-realm
      // intrinsics, so `Object.constructor` is the host Function constructor and
      // `Object.constructor("return Date.now()")()` would evaluate arbitrary,
      // non-deterministic (host) code — bypassing the bare-`Function`/`eval` guard
      // below. Reject both `x.constructor` and `x['constructor']` (and __proto__/
      // prototype). Dynamically-built keys (`x["cons"+"tructor"]`) are out of scope
      // for this static guard — it's a determinism guard, not a hard sandbox.
      const prop = memberPropName(n);
      if (prop === "constructor" || prop === "__proto__" || prop === "prototype") {
        reject(`.${prop} access`);
      }
    }
    // Any value reference to a forbidden global, however it's reached.
    if (n.type === "Identifier" && FORBIDDEN_GLOBALS.has(n.name) && isValueReference(parent, role)) {
      reject(n.name);
    }
  });
}

function evaluateLiteral(node: AnyNode, path: string): unknown {
  switch (node.type) {
    case "ObjectExpression": {
      const out: Record<string, unknown> = {};
      for (const prop of node.properties as AnyNode[]) {
        if (prop.type === "SpreadElement") throw new Error(`spread not allowed in ${path}`);
        if (prop.type !== "Property") throw new Error(`only plain properties allowed in ${path}`);
        if (prop.computed) throw new Error(`computed keys not allowed in ${path}`);
        if (prop.kind !== "init" || prop.method) throw new Error(`methods/accessors not allowed in ${path}`);
        const key = propertyKey(prop.key as AnyNode, path);
        if (key === "__proto__" || key === "constructor" || key === "prototype") {
          throw new Error(`reserved key name not allowed in ${path}: ${key}`);
        }
        out[key] = evaluateLiteral(prop.value as AnyNode, `${path}.${key}`);
      }
      return out;
    }
    case "ArrayExpression":
      return (node.elements as Array<AnyNode | null>).map((element, index) => {
        if (!element) throw new Error(`sparse arrays not allowed in ${path}`);
        if (element.type === "SpreadElement") throw new Error(`spread not allowed in ${path}`);
        return evaluateLiteral(element, `${path}[${index}]`);
      });
    case "Literal":
      return node.value;
    case "TemplateLiteral":
      if (node.expressions.length > 0) throw new Error(`template interpolation not allowed in ${path}`);
      return node.quasis.map((quasi: AnyNode) => quasi.value.cooked ?? quasi.value.raw).join("");
    case "UnaryExpression":
      if (node.operator === "-" && node.argument?.type === "Literal" && typeof node.argument.value === "number") {
        return -node.argument.value;
      }
      throw new Error(`only negative-number unary allowed in ${path}`);
    default:
      throw new Error(`non-literal node type in ${path}: ${node.type}`);
  }
}

function propertyKey(node: AnyNode, path: string): string {
  if (node.type === "Identifier") return node.name;
  if (node.type === "Literal" && (typeof node.value === "string" || typeof node.value === "number"))
    return String(node.value);
  throw new Error(`unsupported key type in ${path}: ${node.type}`);
}

function validateMeta(meta: unknown): asserts meta is WorkflowMeta {
  if (!meta || typeof meta !== "object") throw new Error("meta must be an object");
  const value = meta as WorkflowMeta;
  if (typeof value.name !== "string" || !value.name.trim()) throw new Error("meta.name must be a non-empty string");
  if (typeof value.description !== "string" || !value.description.trim())
    throw new Error("meta.description must be a non-empty string");
  if (value.whenToUse !== undefined && typeof value.whenToUse !== "string")
    throw new Error("meta.whenToUse must be a string");
  if (value.phases !== undefined) {
    if (!Array.isArray(value.phases)) throw new Error("meta.phases must be an array");
    for (const phase of value.phases) {
      if (!phase || typeof phase !== "object" || typeof (phase as WorkflowMetaPhase).title !== "string") {
        throw new Error("each meta phase must have a title string");
      }
    }
  }
}

function createLimiter(limit: number) {
  let active = 0;
  const queue: Array<() => void> = [];
  const next = () => {
    active--;
    queue.shift()?.();
  };
  return async <T>(fn: () => Promise<T>): Promise<T> => {
    if (active >= limit) await new Promise<void>((resolve) => queue.push(resolve));
    active++;
    try {
      return await fn();
    } finally {
      next();
    }
  };
}

function defaultAgentLabel(phase: string | undefined, index: number): string {
  return phase ? `${phase} agent ${index}` : `agent ${index}`;
}

/** Stable identity hash for an agent() call — a cache miss on resume when anything changes. */
function hashAgentCall(
  prompt: string,
  model: string | undefined,
  phase: string | undefined,
  options: AgentOptions,
): string {
  const identity = JSON.stringify({
    prompt,
    model: model ?? null,
    phase: phase ?? null,
    agentType: options.agentType ?? null,
    schema: options.schema ?? null,
  });
  return createHash("sha256").update(identity).digest("hex");
}

function buildAgentInstructions(phase: string | undefined, options: AgentOptions): string | undefined {
  const lines = [];
  if (phase) lines.push(`Workflow phase: ${phase}`);
  if (options.agentType) lines.push(`Act as workflow subagent type: ${options.agentType}`);
  if (options.isolation) lines.push(`Requested isolation: ${options.isolation}`);
  // Note: options.model is applied for real via the session, not injected as prose.
  return lines.length ? lines.join("\n") : undefined;
}

function estimateTokens(value: unknown): number {
  return Math.ceil(JSON.stringify(value ?? "").length / 4);
}
