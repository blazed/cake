/**
 * Workflow manager for background execution, pause/resume, and run management.
 */

import { EventEmitter } from "node:events";
import type { WorkflowAgent } from "./agent.ts";
import { preview, type WorkflowSnapshot } from "./display.ts";
import { WorkflowError, WorkflowErrorCode } from "./errors.ts";
import { profile } from "./profiler.ts";
import {
  createRunPersistence,
  generateRunId,
  type PersistedRunState,
  type RunPersistence,
  type RunStatus,
} from "./run-persistence.ts";
import { type JournalEntry, parseWorkflowScript, runWorkflow, type WorkflowRunResult } from "./workflow.ts";

export interface ManagedRun {
  runId: string;
  status: RunStatus;
  snapshot: WorkflowSnapshot;
  result?: WorkflowRunResult;
  error?: WorkflowError;
  controller: AbortController;
  startedAt: Date;
  /** The real script, kept so the run can be resumed. */
  script: string;
  args?: unknown;
  /** Accumulated agent results for resume (deterministic call index -> result). */
  journal: JournalEntry[];
  /**
   * True when the run was started in the background (or resumed) and the caller is
   * not awaiting its result inline. Only background runs deliver their result back
   * into the conversation; a foreground sync run already returns it as the tool
   * result, so re-delivering would duplicate it.
   */
  background: boolean;
}

/** Per-execution options shared by sync, background, and resume runs. */
export interface ExecOptions {
  /** Replay these journaled agent results for the unchanged prefix (resume). */
  resumeJournal?: Map<number, JournalEntry>;
  /** Cap on total agents for this run. */
  maxAgents?: number;
  /** Per-agent timeout in milliseconds. */
  agentTimeoutMs?: number;
  /** Host signal (e.g. tool/Esc) that should abort this run when fired. */
  externalSignal?: AbortSignal;
  /** Called with the live snapshot on every progress event. */
  onProgress?: (snapshot: WorkflowSnapshot) => void;
}

export interface WorkflowManagerOptions {
  cwd?: string;
  concurrency?: number;
  /** Resolve a saved-workflow name to its script, enabling nested `workflow('name')`. */
  loadSavedWorkflow?: (name: string) => string | undefined;
  /** Inject a custom agent runner (tests); defaults to a real subagent session. */
  agent?: Pick<WorkflowAgent, "run">;
  /** The session's main model (provider/id), for auto-tiering explore agents. */
  mainModel?: string;
}

export class WorkflowManager extends EventEmitter {
  private runs = new Map<string, ManagedRun>();
  private persistence: RunPersistence;
  private cwd: string;
  private concurrency: number;
  private loadSavedWorkflow?: (name: string) => string | undefined;
  private agent?: Pick<WorkflowAgent, "run">;
  /** The session's main model (provider/id), for auto-tiering explore agents. */
  private mainModel?: string;

  constructor(options: WorkflowManagerOptions = {}) {
    super();
    this.cwd = options.cwd ?? process.cwd();
    this.concurrency = options.concurrency ?? 8;
    this.loadSavedWorkflow = options.loadSavedWorkflow;
    this.agent = options.agent;
    this.mainModel = options.mainModel;
    this.persistence = createRunPersistence(this.cwd);
  }

  /** Set the session's main model (provider/id). Used to auto-tier explore agents. */
  setMainModel(spec: string | undefined): void {
    this.mainModel = spec;
  }

  /**
   * Start a workflow in the background.
   * Returns immediately with a run ID; the workflow executes asynchronously.
   */
  startInBackground(
    script: string,
    args?: unknown,
    exec: ExecOptions = {},
  ): { runId: string; promise: Promise<WorkflowRunResult> } {
    const runId = generateRunId();
    const controller = new AbortController();
    const parsed = parseWorkflowScript(script);

    const managed: ManagedRun = {
      runId,
      status: "running",
      snapshot: {
        name: parsed.meta.name,
        description: parsed.meta.description,
        phases: parsed.meta.phases?.map((p) => p.title) ?? [],
        logs: [],
        agents: [],
        agentCount: 0,
        runningCount: 0,
        doneCount: 0,
        errorCount: 0,
      },
      controller,
      startedAt: new Date(),
      script,
      args,
      journal: [],
      background: true,
    };

    this.runs.set(runId, managed);

    // Persist initial state
    this.persistence.save({
      runId,
      workflowName: parsed.meta.name,
      script,
      args,
      status: "running",
      phases: managed.snapshot.phases,
      agents: [],
      logs: [],
      startedAt: managed.startedAt.toISOString(),
      updatedAt: managed.startedAt.toISOString(),
    });

    // Run workflow asynchronously. Errors are surfaced via the "error" event and
    // persisted run state; attach a no-op catch so a rejection on this
    // fire-and-forget promise can't become an unhandled rejection (the returned
    // promise still rejects for any explicit awaiter).
    const promise = this.executeRun(managed, script, args, exec);
    promise.catch(() => {});

    return { runId, promise };
  }

  /**
   * Execute a workflow synchronously (blocking) while still tracking it like a
   * background run, so the `/workflows` navigator and the live task panel see it.
   * `onProgress` fires on every progress event with the current snapshot, letting
   * a caller (e.g. the workflow tool) drive its own inline display.
   */
  async runSync(script: string, args?: unknown, exec: ExecOptions = {}): Promise<WorkflowRunResult> {
    const managed = this.createManaged(script, args);
    this.runs.set(managed.runId, managed);
    // Persist the initial state immediately so listRuns()/the task panel can see
    // the run the moment it starts, not only after the first agent journals.
    this.persistRun(managed);
    return this.executeRun(managed, script, args, exec);
  }

  /** Build a fresh managed run with an empty snapshot. */
  private createManaged(script: string, args?: unknown): ManagedRun {
    const parsed = parseWorkflowScript(script);
    return {
      runId: generateRunId(),
      status: "running",
      snapshot: {
        name: parsed.meta.name,
        description: parsed.meta.description,
        phases: parsed.meta.phases?.map((p) => p.title) ?? [],
        logs: [],
        agents: [],
        agentCount: 0,
        runningCount: 0,
        doneCount: 0,
        errorCount: 0,
      },
      controller: new AbortController(),
      startedAt: new Date(),
      script,
      args,
      journal: [],
      background: false,
    };
  }

  private async executeRun(
    managed: ManagedRun,
    script: string,
    args?: unknown,
    exec: ExecOptions = {},
  ): Promise<WorkflowRunResult> {
    const { resumeJournal, maxAgents, agentTimeoutMs, externalSignal, onProgress } = exec;
    const progress = () => onProgress?.(managed.snapshot);
    // Let a host abort (e.g. Esc during a blocking tool call) cancel this run.
    if (externalSignal) {
      if (externalSignal.aborted) managed.controller.abort();
      else externalSignal.addEventListener("abort", () => managed.controller.abort(), { once: true });
    }
    try {
      const result = await runWorkflow(script, {
        cwd: this.cwd,
        args,
        agent: this.agent,
        mainModel: this.mainModel,
        signal: managed.controller.signal,
        concurrency: this.concurrency,
        maxAgents,
        agentTimeoutMs,
        loadSavedWorkflow: this.loadSavedWorkflow,
        resumeJournal,
        resumeFromRunId: resumeJournal ? managed.runId : undefined,
        onAgentJournal: (entry) => {
          // Append (crash-safe-ish): keep the latest entry per index, then persist.
          // Debounced async write — this fires once per agent completion, so a
          // wide fan-out must not block the TUI on synchronous disk I/O here.
          managed.journal = managed.journal.filter((e) => e.index !== entry.index);
          managed.journal.push(entry);
          this.persistRun(managed, true);
        },
        onLog: (message) => {
          managed.snapshot.logs.push(message);
          this.emit("log", { runId: managed.runId, message });
          progress();
        },
        onPhase: (title) => {
          managed.snapshot.currentPhase = title;
          if (!managed.snapshot.phases.includes(title)) {
            managed.snapshot.phases.push(title);
          }
          this.emit("phase", { runId: managed.runId, title });
          progress();
        },
        onAgentStart: (event) => {
          managed.snapshot.agents.push({
            id: managed.snapshot.agents.length + 1,
            label: event.label,
            phase: event.phase,
            prompt: event.prompt,
            status: "running",
            model: event.model,
          });
          this.emit("agentStart", { runId: managed.runId, ...event });
          progress();
        },
        onAgentEnd: (event) => {
          const agent = [...managed.snapshot.agents]
            .reverse()
            .find((a) => a.label === event.label && a.status === "running");
          if (agent) {
            agent.status = event.result === null ? "error" : "done";
            agent.resultPreview = profile("manager:preview", () => preview(event.result));
            agent.tokens = event.tokens;
            if (event.model) agent.model = event.model;
          }
          profile("emit:agentEnd", () => this.emit("agentEnd", { runId: managed.runId, ...event }));
          progress();
        },
        onTokenUsage: (usage) => {
          managed.snapshot.tokenUsage = usage;
          this.emit("tokenUsage", { runId: managed.runId, usage });
          progress();
        },
      });

      // Enforce the "must run ≥1 agent" contract for ALL modes (background and
      // sync). Routing it through the catch below marks the run failed + emits
      // "error", so a background run can't silently complete with zero agents.
      if (result.agentCount === 0) {
        throw new WorkflowError(
          "workflow scripts must call agent() at least once; this workflow declared phases but ran no subagents",
          WorkflowErrorCode.SCRIPT_VALIDATION_ERROR,
          { recoverable: false },
        );
      }

      managed.status = "completed";
      managed.result = result;
      this.emit("complete", { runId: managed.runId, result });

      // Persist final state
      this.persistRun(managed);

      return result;
    } catch (error) {
      const workflowError =
        error instanceof WorkflowError
          ? error
          : new WorkflowError(
              error instanceof Error ? error.message : String(error),
              WorkflowErrorCode.WORKFLOW_ABORTED,
              { recoverable: true },
            );

      // pause()/stop() already set the terminal status and emitted their event
      // before aborting; don't reclassify the resulting abort as a failure or
      // emit a duplicate "error" for it.
      if (managed.status === "paused" || managed.status === "aborted") {
        managed.error = workflowError;
      } else {
        managed.status = managed.controller.signal.aborted ? "aborted" : "failed";
        managed.error = workflowError;
        this.emit("error", { runId: managed.runId, error: workflowError });
      }

      // Persist final state
      this.persistRun(managed);

      throw workflowError;
    }
  }

  private persistRun(managed: ManagedRun, debounce = false) {
    const state: PersistedRunState = {
      runId: managed.runId,
      workflowName: managed.snapshot.name,
      // Persist the real script + journal so the run can be resumed. Runs live
      // under .pi/workflows/runs/ — protect via directory permissions, not blanking.
      script: managed.script,
      args: managed.args,
      journal: managed.journal,
      status: managed.status,
      phases: managed.snapshot.phases,
      currentPhase: managed.snapshot.currentPhase,
      agents: managed.snapshot.agents.map((a) => ({
        ...a,
        startedAt: managed.startedAt.toISOString(),
        endedAt: new Date().toISOString(),
      })),
      logs: managed.snapshot.logs,
      result: managed.result?.result,
      tokenUsage: managed.snapshot.tokenUsage
        ? {
            input: managed.snapshot.tokenUsage.input,
            output: managed.snapshot.tokenUsage.output,
            total: managed.snapshot.tokenUsage.total,
          }
        : undefined,
      startedAt: managed.startedAt.toISOString(),
      updatedAt: new Date().toISOString(),
      completedAt: managed.status === "completed" ? new Date().toISOString() : undefined,
      durationMs: managed.result?.durationMs,
    };
    // Hot path (per-agent progress) coalesces async; terminal states write sync.
    if (debounce) this.persistence.scheduleSave(state);
    else profile("persist:save(sync)", () => this.persistence.save(state));
  }

  /**
   * Pause a running workflow.
   */
  pause(runId: string): boolean {
    const managed = this.runs.get(runId);
    if (managed?.status !== "running") return false;

    managed.controller.abort();
    managed.status = "paused";
    this.emit("paused", { runId });
    this.persistRun(managed);
    return true;
  }

  /**
   * Resume an interrupted run: replay journaled results for the unchanged prefix
   * and run the rest live. Returns false if there is nothing resumable.
   */
  async resume(runId: string): Promise<boolean> {
    const active = this.runs.get(runId);
    if (active?.status === "running") return false; // already running

    const persisted = this.persistence.load(runId);
    if (!persisted?.script || persisted.status === "completed") return false;

    const controller = new AbortController();
    const managed: ManagedRun = {
      runId,
      status: "running",
      snapshot: {
        name: persisted.workflowName,
        phases: persisted.phases ?? [],
        logs: persisted.logs ?? [],
        agents: [],
        agentCount: 0,
        runningCount: 0,
        doneCount: 0,
        errorCount: 0,
      },
      controller,
      startedAt: new Date(),
      script: persisted.script,
      args: persisted.args,
      journal: persisted.journal ?? [],
      background: true,
    };
    this.runs.set(runId, managed);

    const resumeJournal = new Map((persisted.journal ?? []).map((e) => [e.index, e] as const));
    this.emit("resumed", { runId });
    // Run in the background; executeRun records status/errors on the managed run.
    void this.executeRun(managed, persisted.script, persisted.args, { resumeJournal }).catch(() => {});
    return true;
  }

  /**
   * Stop a running workflow.
   */
  stop(runId: string): boolean {
    const managed = this.runs.get(runId);
    if (!managed || (managed.status !== "running" && managed.status !== "paused")) return false;

    managed.controller.abort();
    managed.status = "aborted";
    this.emit("stopped", { runId });
    this.persistRun(managed);
    return true;
  }

  /**
   * Get status of a specific run.
   */
  getRun(runId: string): ManagedRun | undefined {
    return this.runs.get(runId);
  }

  /**
   * List all runs (active + persisted). Reads from disk — for the on-demand
   * /workflows navigator/commands, NOT the render hot path (see listActiveRuns).
   */
  listRuns(): PersistedRunState[] {
    return this.persistence.list();
  }

  /**
   * Active (running/paused) runs from the in-memory map — no disk I/O. The live
   * task panel renders from this on the TUI hot path; only the /workflows
   * navigator needs the full on-disk history via listRuns().
   */
  listActiveRuns(): ManagedRun[] {
    const out: ManagedRun[] = [];
    for (const run of this.runs.values()) {
      if (run.status === "running" || run.status === "paused") out.push(run);
    }
    return out;
  }

  /**
   * Get snapshot of a run.
   */
  getSnapshot(runId: string): WorkflowSnapshot | null {
    return this.runs.get(runId)?.snapshot ?? null;
  }

  /**
   * Delete a persisted run.
   */
  deleteRun(runId: string): boolean {
    this.runs.delete(runId);
    return this.persistence.delete(runId);
  }

  /**
   * Get the persistence layer (for saving workflows).
   */
  getPersistence(): RunPersistence {
    return this.persistence;
  }
}
