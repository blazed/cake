import type { ExtensionAPI, ExtensionCommandContext, ExtensionContext } from "@earendil-works/pi-coding-agent";
import { isToolCallEventType } from "@earendil-works/pi-coding-agent";
import { Key } from "@earendil-works/pi-tui";
import { Type } from "typebox";
import {
  buildPlanFileSummary,
  createInitialState,
  extractPlanTitle,
  generateUniquePlanPath,
  isPlanFileTarget,
  readPlan,
  resolvePlanTargetPath,
  sanitizePlanModeState,
  type PlanModeState,
  writePlan,
} from "./utils.ts";

const STATUS_KEY = "blazed-plan-mode";
const WIDGET_KEY = "blazed-plan-mode-widget";
const STATE_ENTRY = "blazed-plan-mode-state";
const PLAN_CONTEXT_TYPE = "blazed-plan-mode-context";
const LEGACY_APPROVED_CONTEXT_TYPE = "blazed-approved-plan-context";

const PLAN_TOOL_NAMES = [
  "read",
  "grep",
  "find",
  "ls",
  "web_search",
  "fetch_content",
  "get_search_content",
  "code_search",
  "ask_user_question",
  "todo",
  "jj_context",
  "jj_todo",
  "write",
  "edit",
  "EnterPlanMode",
  "ExitPlanMode",
];

const WRITE_TOOL_NAMES = new Set(["write", "edit"]);

const APPROVE_HERE = "Approve — implement here";
const APPROVE_FRESH = "Approve — fresh session";
const EDIT_PLAN = "Edit plan";
const REJECT_REVISE = "Reject — revise";
const CANCEL_APPROVAL = "Cancel";

type StoredStateEntry = { type?: string; customType?: string; data?: Partial<PlanModeState> };
type PathInput = { path?: unknown };
type JjTodoInput = { action?: unknown; dryRun?: unknown; fresh?: unknown };

function buildPlanningPrompt(task: string, planPath: string): string {
  return `Enter Pi Plan Mode for this task:\n\n${task}\n\nPlan file: ${planPath}\n\nStart by exploring the codebase with non-mutating tools. Keep the plan file self-contained and updated as you learn. Ask the user only for preferences or tradeoff decisions that cannot be discovered from the repository. Do not implement. When the plan is ready, call ExitPlanMode.`;
}

function buildPlanModeInstructions(planPath: string, existingPlan: string | null): string {
  const currentPlan = existingPlan?.trim()
    ? `\nCurrent plan file content:\n\n${existingPlan.trim()}\n`
    : "\nThe plan file is empty. Create a self-contained plan before requesting approval.\n";

  return `[PLAN MODE ACTIVE]\nYou are in Pi Plan Mode, a conversation mode for collaborative planning. It is a tool/UI guard, not an OS sandbox. Bash is disabled; do not ask for bash access or claim shell sandboxing.\n\nStrict boundary:\n- Plan only. Do not implement, refactor, run mutating commands, or edit non-plan files.\n- The only writable target is the plan file: ${planPath}\n- Approval must happen through the ExitPlanMode tool. Never ask for approval in plain text.\n\nWorkflow:\n1. Explore first with non-mutating tools: read, grep, find, ls, web/code search, jj_context, and jj_todo dry-run previews.\n2. Ask the user only for preference/tradeoff decisions that exploration cannot answer.\n3. Keep updating the plan file as the source of truth. The plan must be self-contained enough for a fresh implementation session.\n4. Include goal, relevant files, ordered implementation steps, validation, risks, and rollback notes where useful.\n5. When ready, call ExitPlanMode and let the approval flow decide whether to implement here, start fresh, revise, or cancel.\n\nTool notes:\n- write/edit may target only the plan file above. If you mention the basename, it will be redirected to that exact file.\n- jj_context is forced to fresh=false in plan mode.\n- jj_todo create/update is allowed only with dryRun: true and fresh=false.\n- The normal todo tool is not a substitute for the plan file.\n${currentPlan}`;
}

function buildImplementationPrompt(plan: string, planPath: string): string {
  return `Implement this approved plan step by step.\n\nPlan file: ${planPath}\n\n${plan.trim()}\n\nPlan mode has been deactivated and normal tools are available again. If progress tracking would help, initialize and maintain the normal todo tool. Do not rely on plan-mode widgets or [DONE:n] markers for extension state. If reality differs from the plan, pause and explain the required adjustment before making broad changes.`;
}

function buildPlanReview(plan: string, planPath: string): string {
  return `📋 Plan Review\n\n${plan}\n\n${buildPlanFileSummary(plan, planPath)}`;
}

function hasDeleteOrRenameOperation(value: unknown): boolean {
  if (Array.isArray(value)) return value.some(hasDeleteOrRenameOperation);
  if (!value || typeof value !== "object") return false;

  for (const [key, child] of Object.entries(value as Record<string, unknown>)) {
    const normalizedKey = key.toLowerCase();
    if (["delete", "rename", "remove", "unlink", "move"].includes(normalizedKey)) return true;
    if (["action", "operation", "op"].includes(normalizedKey) && typeof child === "string") {
      if (["delete", "rename", "remove", "unlink", "move", "rm", "mv"].includes(child.toLowerCase())) return true;
    }
    if (hasDeleteOrRenameOperation(child)) return true;
  }

  return false;
}

function isCustomContextMessage(message: unknown, customType: string): boolean {
  return !!message && typeof message === "object" && (message as { customType?: unknown }).customType === customType;
}

export default function blazedPlanMode(pi: ExtensionAPI): void {
  let state: PlanModeState = createInitialState();

  function ensurePlan(ctx: ExtensionContext): string {
    if (!state.planFilePath) {
      const generated = generateUniquePlanPath(ctx.cwd);
      state.planFilePath = generated.path;
      state.planSlug = generated.slug;
      writePlan(generated.path, "");
    }
    return state.planFilePath;
  }

  function persistState(): void {
    pi.appendEntry(STATE_ENTRY, state);
  }

  function planModeToolNames(): string[] {
    const available = new Set(pi.getAllTools().map((tool) => tool.name));
    return PLAN_TOOL_NAMES.filter((name) => available.has(name));
  }

  function setPlanModeTools(): void {
    pi.setActiveTools(planModeToolNames());
  }

  function restorePreviousTools(): void {
    const available = new Set(pi.getAllTools().map((tool) => tool.name));
    const previous = state.previousToolNames?.filter((name) => available.has(name));
    pi.setActiveTools(previous && previous.length > 0 ? previous : [...available]);
    state.previousToolNames = null;
  }

  function updateUI(ctx: ExtensionContext): void {
    if (!ctx.hasUI) return;
    if (state.active) {
      ctx.ui.setStatus(STATUS_KEY, ctx.ui.theme.fg("warning", "⏸ plan"));
      ctx.ui.setWidget(WIDGET_KEY, [
        ctx.ui.theme.fg("warning", "Plan Mode") + ctx.ui.theme.fg("muted", ` — ${state.planFilePath ?? "no plan file"}`),
      ]);
      return;
    }
    ctx.ui.setStatus(STATUS_KEY, undefined);
    ctx.ui.setWidget(WIDGET_KEY, undefined);
  }

  function enterPlanMode(ctx: ExtensionContext, _task?: string): string {
    if (!state.active) state.previousToolNames = pi.getActiveTools();
    const planPath = ensurePlan(ctx);
    state.active = true;
    state.pendingFreshImplementation = null;
    setPlanModeTools();
    persistState();
    updateUI(ctx);
    return planPath;
  }

  function exitPlanMode(ctx: ExtensionContext, reason: "approved" | "cancelled"): void {
    state.active = false;
    if (reason === "cancelled") state.pendingFreshImplementation = null;
    restorePreviousTools();
    persistState();
    updateUI(ctx);
  }

  function restoreState(ctx: ExtensionContext): void {
    state = createInitialState();
    for (const entry of ctx.sessionManager.getEntries().slice().reverse()) {
      const candidate = entry as StoredStateEntry;
      if (candidate.type === "custom" && candidate.customType === STATE_ENTRY) {
        state = sanitizePlanModeState(candidate.data);
        break;
      }
    }

    if (pi.getFlag("plan") === true) enterPlanMode(ctx);
    else if (state.active) {
      ensurePlan(ctx);
      setPlanModeTools();
      persistState();
      updateUI(ctx);
    } else {
      updateUI(ctx);
    }
  }

  function guardPlanFileWrite(event: { toolName: string; input: Record<string, unknown> }, ctx: ExtensionContext) {
    const input = event.input as PathInput;
    if (typeof input.path !== "string") {
      return { block: true, reason: "Plan mode blocked write/edit without a path." };
    }

    const targetPath = resolvePlanTargetPath(input.path, ctx.cwd, state.planFilePath);
    if (!targetPath || !isPlanFileTarget(input.path, ctx.cwd, state.planFilePath)) {
      return { block: true, reason: `Plan mode allows writes only to the plan file: ${state.planFilePath}` };
    }

    if (event.toolName === "edit" && hasDeleteOrRenameOperation(event.input)) {
      return { block: true, reason: "Plan mode blocks delete/rename-like edit operations." };
    }

    input.path = targetPath;
  }

  async function performFreshHandoff(ctx: ExtensionCommandContext): Promise<void> {
    const planPath = state.pendingFreshImplementation?.planFilePath ?? state.lastApprovedPlanFilePath;
    if (!planPath) {
      ctx.ui.notify("No approved plan is queued for a fresh session.", "warning");
      return;
    }

    const plan = readPlan(planPath) ?? "";
    if (!plan.trim()) {
      ctx.ui.notify(`Approved plan is empty or missing: ${planPath}`, "error");
      return;
    }

    if (state.active) exitPlanMode(ctx, "approved");
    state.pendingFreshImplementation = null;
    state.lastApprovedPlanFilePath = planPath;
    persistState();

    const title = extractPlanTitle(plan);
    const prompt = buildImplementationPrompt(plan, planPath);
    const parentSession = ctx.sessionManager.getSessionFile();
    const result = await ctx.newSession({
      parentSession,
      setup: async (sessionManager) => {
        sessionManager.appendSessionInfo(title);
      },
      withSession: async (replacementCtx) => {
        await replacementCtx.sendUserMessage(prompt);
      },
    });

    if (result.cancelled) {
      ctx.ui.notify("Fresh-session plan handoff was cancelled.", "warning");
    }
  }

  async function runApprovalLoop(ctx: ExtensionContext): Promise<string> {
    const planPath = ensurePlan(ctx);
    const plan = readPlan(planPath) ?? "";
    if (!plan.trim()) return `No plan found in ${planPath}. Write the plan file before calling ExitPlanMode.`;
    if (!ctx.hasUI) return "ExitPlanMode requires an interactive/RPC UI approval flow; no approval was granted.";

    const title = extractPlanTitle(plan);
    const choice = await ctx.ui.select(`Review plan: ${title}`, [
      APPROVE_HERE,
      APPROVE_FRESH,
      EDIT_PLAN,
      REJECT_REVISE,
      CANCEL_APPROVAL,
    ]);

    if (choice === APPROVE_HERE) {
      state.lastApprovedPlanFilePath = planPath;
      state.pendingFreshImplementation = null;
      pi.setSessionName(title);
      exitPlanMode(ctx, "approved");
      pi.sendUserMessage(buildImplementationPrompt(plan, planPath), { deliverAs: "followUp" });
      return `Plan approved. Queued implementation in this session for ${planPath}.`;
    }

    if (choice === APPROVE_FRESH) {
      state.lastApprovedPlanFilePath = planPath;
      state.pendingFreshImplementation = { planFilePath: planPath, requestedAt: new Date().toISOString() };
      exitPlanMode(ctx, "approved");
      pi.sendUserMessage("/plan fresh", { deliverAs: "followUp" });
      return `Plan approved. Queued a fresh-session handoff for ${planPath}.`;
    }

    if (choice === EDIT_PLAN) {
      const edited = await ctx.ui.editor("Edit plan", plan);
      if (typeof edited !== "string") return "Plan edit cancelled. Stay in plan mode and call ExitPlanMode when ready.";
      writePlan(planPath, edited);
      persistState();
      return `Plan file updated: ${planPath}. Stay in plan mode, review the update, and call ExitPlanMode again when ready.`;
    }

    if (choice === REJECT_REVISE) {
      const feedback = await ctx.ui.editor("Revision feedback for the agent", "");
      const note = feedback?.trim()
        ? `\n\nUser revision feedback:\n${feedback.trim()}`
        : "\n\nNo specific feedback was provided.";
      return `Plan was not approved. Stay in plan mode, revise the plan file, and call ExitPlanMode again.${note}`;
    }

    return "Plan approval cancelled. Stay in plan mode and call ExitPlanMode when the plan is ready.";
  }

  pi.registerFlag("plan", {
    description: "Start Pi in planning mode with file-backed guardrails",
    type: "boolean",
    default: false,
  });

  pi.registerCommand("plan", {
    description: "Plan before implementing. Usage: /plan <task>, /plan open|review|status|off|clear|fresh",
    handler: async (args, ctx) => {
      const trimmed = args.trim();

      if (trimmed === "fresh") {
        await performFreshHandoff(ctx);
        return;
      }

      if (trimmed === "off") {
        if (state.active) {
          exitPlanMode(ctx, "cancelled");
          ctx.ui.notify("Plan mode cancelled and tools restored.", "info");
        } else {
          ctx.ui.notify("Plan mode is not active.", "info");
        }
        return;
      }

      if (trimmed === "status") {
        const plan = readPlan(state.planFilePath);
        ctx.ui.notify(
          `Plan mode status\n\nActive: ${state.active ? "yes" : "no"}\n${buildPlanFileSummary(plan, state.planFilePath)}\nApproved plan: ${state.lastApprovedPlanFilePath ?? "none"}\nPending fresh handoff: ${state.pendingFreshImplementation?.planFilePath ?? "none"}\nActive tools: ${pi.getActiveTools().join(", ")}`,
          "info",
        );
        return;
      }

      if (trimmed === "review") {
        const planPath = ensurePlan(ctx);
        ctx.ui.notify(buildPlanReview(readPlan(planPath) ?? "", planPath), "info");
        return;
      }

      if (trimmed === "open") {
        const planPath = ensurePlan(ctx);
        const edited = await ctx.ui.editor("Edit plan", readPlan(planPath) ?? "");
        if (typeof edited !== "string") {
          ctx.ui.notify("Plan edit cancelled.", "info");
          return;
        }
        writePlan(planPath, edited);
        persistState();
        ctx.ui.notify(`Plan saved: ${planPath}`, "info");
        return;
      }

      if (trimmed === "clear") {
        const planPath = ensurePlan(ctx);
        const ok = !ctx.hasUI || (await ctx.ui.confirm("Clear plan?", `Empty the current plan file?\n\n${planPath}`));
        if (!ok) {
          ctx.ui.notify("Plan clear cancelled.", "info");
          return;
        }
        writePlan(planPath, "");
        state.lastApprovedPlanFilePath = null;
        state.pendingFreshImplementation = null;
        persistState();
        ctx.ui.notify(`Plan cleared: ${planPath}`, "info");
        return;
      }

      if (!trimmed) {
        if (state.active) {
          const planPath = ensurePlan(ctx);
          ctx.ui.notify(buildPlanReview(readPlan(planPath) ?? "", planPath), "info");
        } else {
          const planPath = enterPlanMode(ctx);
          ctx.ui.notify(`Plan mode enabled. Plan file: ${planPath}`, "info");
        }
        return;
      }

      const planPath = enterPlanMode(ctx, trimmed);
      ctx.ui.notify(`Plan mode enabled. Plan file: ${planPath}`, "info");
      pi.sendUserMessage(buildPlanningPrompt(trimmed, planPath), { deliverAs: "followUp" });
    },
  });

  pi.registerShortcut(Key.ctrlAlt("p"), {
    description: "Toggle plan mode",
    handler: async (ctx) => {
      if (state.active) {
        exitPlanMode(ctx, "cancelled");
        ctx.ui.notify("Plan mode disabled.", "info");
      } else {
        const planPath = enterPlanMode(ctx);
        ctx.ui.notify(`Plan mode enabled. Plan file: ${planPath}`, "info");
      }
    },
  });

  pi.registerTool({
    name: "EnterPlanMode",
    label: "Enter Plan Mode",
    description: "Enter planning mode with non-mutating guardrails before implementing a non-trivial task.",
    promptSnippet: "EnterPlanMode starts file-backed planning before coding",
    promptGuidelines: [
      "Use EnterPlanMode before implementation when a task needs planning or user approval.",
      "After EnterPlanMode succeeds, write the plan file and do not implement until ExitPlanMode approval.",
    ],
    parameters: Type.Object({}),
    async execute(_toolCallId, _params, _signal, _onUpdate, ctx) {
      if (state.active) {
        return { content: [{ type: "text", text: `Already in plan mode. Plan file: ${ensurePlan(ctx)}` }], details: { active: true } };
      }
      if (ctx.hasUI) {
        const approved = await ctx.ui.confirm(
          "Enter Plan Mode?",
          "The agent wants to plan before implementing. Approve switching to plan mode?",
        );
        if (!approved) {
          return { content: [{ type: "text", text: "User declined EnterPlanMode." }], details: { approved: false } };
        }
      }
      const planPath = enterPlanMode(ctx);
      return {
        content: [{ type: "text", text: `EnterPlanMode activated. Plan file: ${planPath}. Call ExitPlanMode when the plan is complete.` }],
        details: { approved: true, planFilePath: planPath },
      };
    },
  });

  pi.registerTool({
    name: "ExitPlanMode",
    label: "Exit Plan Mode",
    description: "Present the current plan for user approval. Use only when the plan file is ready for review.",
    promptSnippet: "ExitPlanMode presents the plan file for approval before implementation",
    promptGuidelines: [
      "Only call ExitPlanMode after writing a complete plan file.",
      "Do not ask for plan approval in plain text; call ExitPlanMode.",
      "If ExitPlanMode returns rejection feedback, stay in plan mode and revise the plan file.",
    ],
    parameters: Type.Object({}),
    async execute(_toolCallId, _params, _signal, _onUpdate, ctx) {
      if (!state.active) {
        return { content: [{ type: "text", text: "Not currently in plan mode." }], details: { active: false } };
      }
      const text = await runApprovalLoop(ctx);
      return { content: [{ type: "text", text }], details: { active: state.active, planFilePath: state.planFilePath } };
    },
  });

  pi.on("tool_call", async (event, ctx) => {
    if (!state.active) return;

    if (isToolCallEventType("write", event) || isToolCallEventType("edit", event)) {
      return guardPlanFileWrite(event, ctx);
    }

    if (event.toolName === "bash") {
      return { block: true, reason: "Plan mode disables bash instead of pretending a shell allowlist is a sandbox." };
    }

    if (WRITE_TOOL_NAMES.has(event.toolName)) {
      return { block: true, reason: `Plan mode blocks mutating tool ${event.toolName}.` };
    }

    if (event.toolName === "jj_context") {
      (event.input as { fresh?: unknown }).fresh = false;
      return;
    }

    if (event.toolName === "jj_todo") {
      const input = event.input as JjTodoInput;
      input.fresh = false;
      if ((input.action === "create" || input.action === "update") && input.dryRun !== true) {
        return { block: true, reason: "Plan mode blocks mutating jj_todo actions; use dryRun: true to preview." };
      }
      return;
    }

    if (PLAN_TOOL_NAMES.includes(event.toolName)) return;

    return { block: true, reason: `Plan mode blocks tool "${event.toolName}" because it is not explicitly allowed.` };
  });

  pi.on("context", async (event) => {
    if (state.active) return;
    return {
      messages: event.messages.filter(
        (message) => !isCustomContextMessage(message, PLAN_CONTEXT_TYPE) && !isCustomContextMessage(message, LEGACY_APPROVED_CONTEXT_TYPE),
      ),
    };
  });

  pi.on("before_agent_start", async (event, ctx) => {
    if (!state.active) return;
    const planPath = ensurePlan(ctx);
    return {
      message: {
        customType: PLAN_CONTEXT_TYPE,
        content: buildPlanModeInstructions(planPath, readPlan(planPath)),
        display: false,
      },
      systemPrompt: `${event.systemPrompt}\n\n[PLAN MODE] Planning is active. Do not implement. Bash is disabled. Write only the plan file and call ExitPlanMode for approval.`,
    };
  });

  pi.on("session_start", async (_event, ctx) => {
    restoreState(ctx);
  });

  pi.on("session_shutdown", async (_event, ctx) => {
    if (!ctx.hasUI) return;
    ctx.ui.setStatus(STATUS_KEY, undefined);
    ctx.ui.setWidget(WIDGET_KEY, undefined);
  });
}
