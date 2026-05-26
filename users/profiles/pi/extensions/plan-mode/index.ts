/**
 * Blazed plan mode for Pi.
 *
 * Combines the official Pi plan-mode example with the stronger file-backed,
 * approve-before-implementation flow from community plan-mode extensions.
 */

import type { ExtensionAPI, ExtensionCommandContext, ExtensionContext } from "@earendil-works/pi-coding-agent";
import { isToolCallEventType } from "@earendil-works/pi-coding-agent";
import { Key } from "@earendil-works/pi-tui";
import { Type } from "typebox";
import { execSync } from "node:child_process";
import {
  createInitialState,
  extractPlanTitle,
  extractTodoItems,
  generateUniquePlanPath,
  isSafeReadOnlyCommand,
  markCompletedSteps,
  readPlan,
  samePath,
  type PlanState,
  type TodoItem,
  writePlan,
} from "./utils.ts";

const STATUS_KEY = "blazed-plan-mode";
const WIDGET_KEY = "blazed-plan-mode-widget";
const STATE_ENTRY = "blazed-plan-mode-state";
const EXECUTE_ENTRY = "blazed-plan-mode-execute";

const WRITE_TOOLS = new Set(["write", "edit", "ast_rewrite"]);
const ALWAYS_SAFE_TOOLS = new Set([
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
  "EnterPlanMode",
  "ExitPlanMode",
]);

function assistantText(message: unknown): string {
  const candidate = message as { role?: unknown; content?: unknown };
  if (candidate.role !== "assistant") return "";
  if (typeof candidate.content === "string") return candidate.content;
  if (!Array.isArray(candidate.content)) return "";
  return candidate.content
    .map((block) => {
      const value = block as { type?: unknown; text?: unknown };
      return value.type === "text" && typeof value.text === "string" ? value.text : "";
    })
    .filter(Boolean)
    .join("\n");
}

function buildPlanningPrompt(task: string, planPath: string): string {
  return `Enter plan mode for this task:\n\n${task}\n\nYour plan file is: ${planPath}\n\nStart with read-only exploration. Write or update the plan file as you learn. Ask concise user-answerable questions if requirements or tradeoffs are ambiguous. When the plan is ready, call ExitPlanMode for approval.`;
}

function buildImplementationPrompt(plan: string, planPath: string): string {
  return `Implement this approved plan step by step.\n\nPlan file: ${planPath}\n\n${plan}\n\nFollow the plan. After completing each tracked step, include a [DONE:n] marker in your response. If reality differs from the plan, pause and explain the required adjustment before making broad changes.`;
}

function buildPlanReview(plan: string, planPath: string): string {
  return `📋 Plan Review\n\n${plan}\n\nPlan file: ${planPath}`;
}

function buildPlanModeInstructions(planPath: string, existingPlan: string | null, reentry: boolean): string {
  return `[PLAN MODE ACTIVE]
You are in read-only plan mode. The user wants detailed planning before implementation.

Plan file: ${planPath}
${existingPlan?.trim() ? `\nCurrent plan content:\n${existingPlan.trim()}\n` : ""}
${reentry ? "\nYou are re-entering plan mode after a prior approval/exit. Read and reassess the existing plan before revising it.\n" : ""}
Hard restrictions:
- Do not implement until the user approves via ExitPlanMode.
- Do not write/edit any file except the plan file above.
- Do not run mutating shell commands, installs, VCS mutations, switches, or destructive commands.
- Use read-only exploration tools and bash only for read-only inspection.

Planning workflow:
1. Explore first: inspect relevant files, symbols, configs, tests, and docs. Do not make evidence-free plans.
2. Capture findings in the plan file as you go; do not wait until the end.
3. Ask only user-answerable questions. Never ask what you can discover by reading code.
4. Converge when the plan names exact files/functions to change, existing utilities to reuse, validation commands, risks, and rollback notes.
5. Call ExitPlanMode when the plan is ready. Do not ask for approval in plain text.

Plan file format:
# Plan: <short name>

## Goal
One paragraph describing done.

## Evidence
- \`path/to/file\`: what you verified

## Assumptions / Decisions
- Record clarified requirements and tradeoffs.

## Critical Files
- \`path/to/file\`: why it matters

## Tasks
### Task 1: <component>
- [ ] Concrete 5-15 minute implementation step with exact names/paths
- [ ] Concrete validation or test step
- [ ] Commit: \`type(scope): message\`

## Verification
- Specific commands/checks to run.

## Risks / Rollback
- Risks, compatibility notes, and how to back out.

Quality bar:
- Zero placeholders: no TBD, "as needed", or vague "update config" steps.
- A developer should be able to execute the plan without architectural guessing.`;
}

export default function blazedPlanMode(pi: ExtensionAPI): void {
  let state: PlanState = createInitialState();
  let executionMode = false;
  let todoItems: TodoItem[] = [];
  let lastCommandCtx: ExtensionCommandContext | null = null;

  function ensurePlan(ctx: ExtensionContext): string {
    if (!state.planFilePath) {
      const generated = generateUniquePlanPath(ctx.cwd);
      state.planSlug = generated.slug;
      state.planFilePath = generated.path;
      writePlan(generated.path, "");
    }
    return state.planFilePath;
  }

  function persistState(): void {
    pi.appendEntry(STATE_ENTRY, {
      ...state,
      executionMode,
      todoItems,
    });
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

    if (executionMode && todoItems.length > 0) {
      const completed = todoItems.filter((item) => item.completed).length;
      ctx.ui.setStatus(STATUS_KEY, ctx.ui.theme.fg("accent", `📋 ${completed}/${todoItems.length}`));
      ctx.ui.setWidget(
        WIDGET_KEY,
        todoItems.map((item) =>
          item.completed
            ? ctx.ui.theme.fg("success", "☑ ") + ctx.ui.theme.fg("muted", ctx.ui.theme.strikethrough(item.text))
            : `${ctx.ui.theme.fg("muted", "☐ ")}${item.text}`,
        ),
      );
      return;
    }

    ctx.ui.setStatus(STATUS_KEY, undefined);
    ctx.ui.setWidget(WIDGET_KEY, undefined);
  }

  function activatePlanMode(ctx: ExtensionContext): string {
    const planPath = ensurePlan(ctx);
    state.active = true;
    state.lastTransition = "entered";
    executionMode = false;
    todoItems = [];
    persistState();
    updateUI(ctx);
    return planPath;
  }

  function deactivatePlanMode(ctx: ExtensionContext, transition: "approved" | "cancelled" | null): void {
    state.active = false;
    state.lastTransition = transition;
    state.hasExitedPlanModeInSession = transition === "approved" || state.hasExitedPlanModeInSession;
    persistState();
    updateUI(ctx);
  }

  async function approveCurrentPlan(ctx: ExtensionContext, editedDuringReview: boolean, freshSession: boolean): Promise<string> {
    const planPath = ensurePlan(ctx);
    const plan = readPlan(planPath) ?? "";
    state.lastApprovedPlanFilePath = planPath;
    state.lastTransition = "approved";
    state.hasExitedPlanModeInSession = true;
    executionMode = true;
    todoItems = extractTodoItems(plan);
    pi.setSessionName(extractPlanTitle(plan));
    pi.appendEntry(EXECUTE_ENTRY, { planFilePath: planPath, todoItems, freshSession });
    deactivatePlanMode(ctx, "approved");
    updateUI(ctx);

    const implementationPrompt = buildImplementationPrompt(plan, planPath);
    const prefix = editedDuringReview ? "Plan approved after edits." : "Plan approved.";

    if (!freshSession) return `${prefix}\n\n${implementationPrompt}`;

    if (!lastCommandCtx) {
      return `${prefix}\n\nI could not start a fresh session from this approval context. Run /plan fresh to clear the planning context and implement from the approved plan file.`;
    }

    const result = await lastCommandCtx.newSession({
      parentSession: ctx.sessionManager.getSessionFile(),
      withSession: async (newCtx) => {
        await newCtx.sendUserMessage(implementationPrompt);
      },
    });

    if (result.cancelled) {
      return `${prefix}\n\nFresh session creation was cancelled. Run /plan fresh later, or implement in this session with:\n\n${implementationPrompt}`;
    }

    return `${prefix}\n\nStarted a fresh implementation session seeded only with the approved plan.`;
  }

  async function runApprovalLoop(ctx: ExtensionContext): Promise<string> {
    const planPath = ensurePlan(ctx);
    let plan = readPlan(planPath) ?? "";
    if (!plan.trim()) return `No plan found in ${planPath}. Write a plan first, then call ExitPlanMode again.`;

    if (!ctx.hasUI) return approveCurrentPlan(ctx, false, false);

    let editedDuringReview = false;
    while (true) {
      ctx.ui.notify(buildPlanReview(plan, planPath), "info");
      const choice = await ctx.ui.select("How would you like to proceed?", [
        "✓ Accept — implement here",
        "↻ Accept — clear context and implement",
        "✎ Edit plan first",
        "✗ Reject — give feedback",
        "⟳ Start over",
      ]);

      if (!choice) return "Plan review dismissed. Continue refining the plan and call ExitPlanMode when ready.";

      if (choice.startsWith("✓")) return approveCurrentPlan(ctx, editedDuringReview, false);
      if (choice.startsWith("↻")) return approveCurrentPlan(ctx, editedDuringReview, true);

      if (choice.startsWith("✎")) {
        const editor = process.env.EDITOR || process.env.VISUAL;
        if (editor) {
          try {
            execSync(`${editor} ${JSON.stringify(planPath)}`, { stdio: "inherit" });
          } catch {
            ctx.ui.notify("Editor closed or failed.", "warning");
          }
        } else {
          const edited = await ctx.ui.editor("Edit Plan", plan);
          if (edited !== undefined) writePlan(planPath, edited);
        }
        plan = readPlan(planPath) ?? plan;
        editedDuringReview = true;
        continue;
      }

      if (choice.startsWith("✗")) {
        const feedback = await ctx.ui.input("What should change?", "Describe what to revise");
        persistState();
        return feedback?.trim()
          ? `Plan rejected. User feedback: ${feedback.trim()}\n\nRevise the plan file and call ExitPlanMode again when ready.`
          : "Plan rejected. Revise the plan file and call ExitPlanMode again when ready.";
      }

      if (choice.startsWith("⟳")) {
        const direction = await ctx.ui.input("New direction?", "Optional focus for the new plan");
        writePlan(planPath, "");
        state.lastApprovedPlanFilePath = null;
        persistState();
        return direction?.trim()
          ? `The user discarded the plan. Start over with this focus: ${direction.trim()}\n\nCreate a fresh plan in ${planPath}.`
          : `The user discarded the plan. Start over and create a fresh plan in ${planPath}.`;
      }
    }
  }

  pi.registerFlag("plan", {
    description: "Start Pi in read-only plan mode",
    type: "boolean",
    default: false,
  });

  pi.registerCommand("plan", {
    description: "Plan before implementing. Usage: /plan <task>, /plan open|review|fresh|status|off|resume|clear",
    handler: async (args, ctx) => {
      const trimmed = args.trim();
      lastCommandCtx = ctx;

      if (trimmed === "off") {
        deactivatePlanMode(ctx, "cancelled");
        ctx.ui.notify("Plan mode cancelled.", "info");
        return;
      }

      if (trimmed === "status") {
        const content = readPlan(state.planFilePath);
        ctx.ui.notify(
          `Plan mode status\n\nActive: ${state.active ? "yes" : "no"}\nExecuting: ${executionMode ? "yes" : "no"}\nPlan file: ${state.planFilePath ?? "none"}\nApproved plan: ${state.lastApprovedPlanFilePath ?? "none"}\nPlan content: ${content?.trim() ? "present" : "empty/missing"}`,
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
        const editor = process.env.EDITOR || process.env.VISUAL;
        if (editor) {
          execSync(`${editor} ${JSON.stringify(planPath)}`, { stdio: "inherit" });
        } else {
          const current = readPlan(planPath) ?? "";
          const edited = await ctx.ui.editor("Edit Plan", current);
          if (edited !== undefined) writePlan(planPath, edited);
        }
        ctx.ui.notify(`Plan saved: ${planPath}`, "info");
        return;
      }

      if (trimmed === "clear") {
        const planPath = ensurePlan(ctx);
        if (ctx.hasUI) {
          const confirmed = await ctx.ui.confirm("Clear plan?", `Erase ${planPath}?`);
          if (!confirmed) return;
        }
        writePlan(planPath, "");
        state.lastApprovedPlanFilePath = null;
        persistState();
        ctx.ui.notify("Plan cleared.", "info");
        return;
      }

      if (trimmed === "resume") {
        const planPath = activatePlanMode(ctx);
        ctx.ui.notify(`Plan mode resumed. Plan file: ${planPath}`, "info");
        return;
      }

      if (trimmed === "fresh") {
        const planPath = state.lastApprovedPlanFilePath ?? state.planFilePath;
        const plan = readPlan(planPath);
        if (!planPath || !plan?.trim()) {
          ctx.ui.notify("No approved plan is available for a fresh session.", "warning");
          return;
        }
        await ctx.newSession({
          parentSession: ctx.sessionManager.getSessionFile(),
          withSession: async (newCtx) => {
            await newCtx.sendUserMessage(buildImplementationPrompt(plan, planPath));
          },
        });
        return;
      }

      if (!trimmed) {
        if (state.active) {
          const planPath = ensurePlan(ctx);
          ctx.ui.notify(buildPlanReview(readPlan(planPath) ?? "", planPath), "info");
        } else {
          const planPath = activatePlanMode(ctx);
          ctx.ui.notify(`Plan mode enabled. Plan file: ${planPath}`, "info");
        }
        return;
      }

      const planPath = activatePlanMode(ctx);
      ctx.ui.notify(`Plan mode enabled. Plan file: ${planPath}`, "info");
      pi.sendUserMessage(buildPlanningPrompt(trimmed, planPath), { deliverAs: "followUp" });
    },
  });

  pi.registerCommand("todos", {
    description: "Show approved plan execution progress",
    handler: async (_args, ctx) => {
      if (todoItems.length === 0) {
        ctx.ui.notify("No tracked approved-plan tasks.", "info");
        return;
      }
      const completed = todoItems.filter((item) => item.completed).length;
      ctx.ui.notify(
        `Plan progress ${completed}/${todoItems.length}\n` +
          todoItems.map((item) => `${item.step}. ${item.completed ? "✓" : "○"} ${item.text}`).join("\n"),
        "info",
      );
    },
  });

  pi.registerShortcut(Key.ctrlAlt("p"), {
    description: "Toggle plan mode",
    handler: async (ctx) => {
      if (state.active) {
        deactivatePlanMode(ctx, "cancelled");
        ctx.ui.notify("Plan mode disabled.", "info");
      } else {
        const planPath = activatePlanMode(ctx);
        ctx.ui.notify(`Plan mode enabled. Plan file: ${planPath}`, "info");
      }
    },
  });

  pi.registerTool({
    name: "EnterPlanMode",
    label: "Enter Plan Mode",
    description: "Enter read-only plan mode before implementing a non-trivial task. Requires user approval in UI mode.",
    promptSnippet: "Enter read-only plan mode and prepare an implementation plan before coding",
    promptGuidelines: [
      "For complex or ambiguous work, use EnterPlanMode before editing code.",
      "In plan mode, write the evolving plan to the plan file and call ExitPlanMode when ready for user approval.",
    ],
    parameters: Type.Object({}),
    async execute(_toolCallId, _params, _signal, _onUpdate, ctx) {
      if (state.active) {
        return { content: [{ type: "text", text: `Already in plan mode. Plan file: ${ensurePlan(ctx)}` }], details: { active: true } };
      }
      if (ctx.hasUI) {
        const approved = await ctx.ui.confirm(
          "Enter Plan Mode?",
          "The agent wants to switch to read-only planning before implementation. Approve?",
        );
        if (!approved) {
          return { content: [{ type: "text", text: "User declined plan mode. Continue normally." }], details: { approved: false } };
        }
      }
      const planPath = activatePlanMode(ctx);
      return {
        content: [{ type: "text", text: `Plan mode activated. Write the plan to ${planPath}, then call ExitPlanMode for approval.` }],
        details: { approved: true, planFilePath: planPath },
      };
    },
  });

  pi.registerTool({
    name: "ExitPlanMode",
    label: "Exit Plan Mode",
    description: "Present the current plan for user approval. Use only when the plan file is ready for review.",
    promptSnippet: "Present the completed plan for approval before implementation",
    promptGuidelines: [
      "Only call ExitPlanMode after writing a complete plan file.",
      "Do not ask for approval in plain text; use ExitPlanMode.",
      "If the user rejects the plan, stay in plan mode and revise the plan file.",
    ],
    parameters: Type.Object({}),
    async execute(_toolCallId, _params, _signal, _onUpdate, ctx) {
      if (!state.active) {
        return { content: [{ type: "text", text: "Not currently in plan mode." }], details: { active: false } };
      }
      const text = await runApprovalLoop(ctx);
      return { content: [{ type: "text", text }], details: { approved: state.lastTransition === "approved", planFilePath: state.planFilePath } };
    },
  });

  pi.on("tool_call", async (event) => {
    if (!state.active) return;

    if (event.toolName === "bash") {
      const command = typeof event.input.command === "string" ? event.input.command : "";
      if (!isSafeReadOnlyCommand(command)) {
        return { block: true, reason: `Plan mode blocked non-read-only bash command: ${command}` };
      }
      return;
    }

    if (isToolCallEventType("write", event) || isToolCallEventType("edit", event)) {
      if (samePath(event.input.path, state.planFilePath)) return;
      return { block: true, reason: `Plan mode allows writes only to the plan file: ${state.planFilePath}` };
    }

    if (WRITE_TOOLS.has(event.toolName)) {
      return { block: true, reason: `Plan mode blocks mutating tool ${event.toolName}.` };
    }

    if (event.toolName === "jj_todo") {
      const input = event.input as { action?: unknown; dryRun?: unknown };
      const action = input.action;
      if ((action === "create" || action === "update") && input.dryRun !== true) {
        return { block: true, reason: "Plan mode blocks mutating jj_todo actions; use dryRun: true to preview." };
      }
    }

    if (ALWAYS_SAFE_TOOLS.has(event.toolName)) return;
  });

  pi.on("before_agent_start", async (event, ctx) => {
    if (state.active) {
      const planPath = ensurePlan(ctx);
      const existingPlan = readPlan(planPath);
      const reentry = state.hasExitedPlanModeInSession;
      if (reentry) {
        state.hasExitedPlanModeInSession = false;
        persistState();
      }
      return {
        message: {
          customType: "blazed-plan-mode-context",
          content: buildPlanModeInstructions(planPath, existingPlan, reentry),
          display: false,
        },
        systemPrompt: `${event.systemPrompt}\n\n[PLAN MODE] Read-only planning is active. Use the plan file and call ExitPlanMode for approval before implementation.`,
      };
    }

    const planPath = state.lastApprovedPlanFilePath;
    const plan = readPlan(planPath);
    if (planPath && plan?.trim()) {
      return {
        message: {
          customType: "blazed-approved-plan-context",
          content: `[APPROVED PLAN]\nPlan file: ${planPath}\n\n${plan}\n\nIf this plan is relevant and not complete, continue following it.`,
          display: false,
        },
      };
    }
  });

  pi.on("turn_end", async (event, ctx) => {
    if (!executionMode || todoItems.length === 0) return;
    const count = markCompletedSteps(assistantText(event.message), todoItems);
    if (count > 0) {
      persistState();
      updateUI(ctx);
    }
    if (todoItems.every((item) => item.completed)) {
      executionMode = false;
      persistState();
      updateUI(ctx);
      ctx.ui.notify("Approved plan complete.", "info");
    }
  });

  pi.on("session_start", async (_event, ctx) => {
    state = createInitialState();
    executionMode = false;
    todoItems = [];

    for (const entry of ctx.sessionManager.getEntries().slice().reverse()) {
      const candidate = entry as { type?: string; customType?: string; data?: Partial<PlanState> & { executionMode?: boolean; todoItems?: TodoItem[] } };
      if (candidate.type === "custom" && candidate.customType === STATE_ENTRY && candidate.data) {
        state = { ...state, ...candidate.data };
        executionMode = candidate.data.executionMode ?? false;
        todoItems = candidate.data.todoItems ?? [];
        break;
      }
    }

    if (pi.getFlag("plan") === true) activatePlanMode(ctx);
    updateUI(ctx);
  });

  pi.on("session_shutdown", async (_event, ctx) => {
    if (!ctx.hasUI) return;
    ctx.ui.setStatus(STATUS_KEY, undefined);
    ctx.ui.setWidget(WIDGET_KEY, undefined);
  });
}
