import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";
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

type StoredStateEntry = { type?: string; customType?: string; data?: Partial<PlanModeState> };
type PathInput = { path?: unknown };
type JjTodoInput = { action?: unknown; dryRun?: unknown; fresh?: unknown };

function buildPlanningPrompt(task: string, planPath: string): string {
  return `Enter plan mode for this task:\n\n${task}\n\nPlan file: ${planPath}\n\nExplore with non-mutating tools, keep the plan file updated, and call ExitPlanMode only when the plan is ready for approval.`;
}

function buildPlanModeInstructions(planPath: string, existingPlan: string | null): string {
  return `[PLAN MODE ACTIVE]\nYou are planning only. Do not implement until ExitPlanMode approval completes.\n\nPlan file: ${planPath}\n${existingPlan?.trim() ? `\nCurrent plan content:\n${existingPlan.trim()}\n` : ""}\nRules:\n- Explore first with read-only tools.\n- Write or edit only the plan file above.\n- Bash is disabled in plan mode.\n- Ask the user only for preferences or tradeoffs that cannot be discovered.\n- Keep the plan self-contained and call ExitPlanMode when ready.`;
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

  async function runApprovalLoop(ctx: ExtensionContext): Promise<string> {
    const planPath = ensurePlan(ctx);
    const plan = readPlan(planPath) ?? "";
    if (!plan.trim()) return `No plan found in ${planPath}. Write the plan file before calling ExitPlanMode.`;
    return `Plan file is ready for approval: ${planPath}. Approval handoff will be handled by the plan-mode approval flow.`;
  }

  pi.registerFlag("plan", {
    description: "Start Pi in planning mode with file-backed guardrails",
    type: "boolean",
    default: false,
  });

  pi.registerCommand("plan", {
    description: "Plan before implementing. Usage: /plan <task>, /plan review|status|off|clear",
    handler: async (args, ctx) => {
      const trimmed = args.trim();

      if (trimmed === "off") {
        exitPlanMode(ctx, "cancelled");
        ctx.ui.notify("Plan mode cancelled.", "info");
        return;
      }

      if (trimmed === "status") {
        const plan = readPlan(state.planFilePath);
        ctx.ui.notify(
          `Plan mode status\n\nActive: ${state.active ? "yes" : "no"}\n${buildPlanFileSummary(plan, state.planFilePath)}\nApproved plan: ${state.lastApprovedPlanFilePath ?? "none"}\nActive tools: ${pi.getActiveTools().join(", ")}`,
          "info",
        );
        return;
      }

      if (trimmed === "review") {
        const planPath = ensurePlan(ctx);
        ctx.ui.notify(buildPlanReview(readPlan(planPath) ?? "", planPath), "info");
        return;
      }

      if (trimmed === "clear") {
        const planPath = ensurePlan(ctx);
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
