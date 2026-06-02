/**
 * Background-run UX, mirroring Claude Code:
 *  - A live task panel below the input lists in-progress runs while you keep working.
 *    It is informational; run /workflows to open the full navigator.
 *  - When a background run finishes, its result is delivered back into the
 *    conversation so the paused task continues with the outcome.
 */

import type { ExtensionAPI, ExtensionUIContext, Theme } from "@earendil-works/pi-coding-agent";
import type { Component, TUI } from "@earendil-works/pi-tui";
import { framePanel } from "./panel-box.ts";
import { profile } from "./profiler.ts";
import type { ManagedRun, WorkflowManager } from "./workflow-manager.ts";
import type { WorkflowStorage } from "./workflow-saved.ts";

const RUN_EVENTS = ["agentStart", "agentEnd", "phase", "log", "complete", "error", "stopped", "paused", "resumed"];

export interface TaskPanelOptions {
  storage?: WorkflowStorage;
  cwd?: string;
}

function deliverText(run: ManagedRun): string {
  const r = run.result?.result as { report?: unknown } | undefined;
  const body =
    r && typeof r.report === "string" && r.report.trim() ? r.report : JSON.stringify(run.result?.result, null, 2);
  const tokens = run.result?.tokenUsage ? ` · ${run.result.tokenUsage.total.toLocaleString()} tokens` : "";
  const agents = run.result?.agentCount ?? run.snapshot.agentCount;
  return [
    `✓ Background workflow "${run.snapshot.name}" finished (${agents} agents${tokens}).`,
    "Continue helping the user based on this result.",
    "",
    body,
  ].join("\n");
}

/**
 * When a background run finishes (or fails), deliver its result back into the
 * conversation AND continue the turn so the assistant can act on it — without
 * blocking the user meanwhile:
 *
 *  - `triggerTurn: true` starts a fresh turn when the agent is idle, feeding the
 *    result to the model so the paused conversation continues.
 *  - `deliverAs: "followUp"` means that if the user is busy in another turn, the
 *    result is queued and picked up after that turn finishes — never interrupting.
 *
 * Set up once per extension; idempotent via an internal guard.
 */
export function installResultDelivery(pi: ExtensionAPI, manager: WorkflowManager): void {
  if ((manager as unknown as { __deliveryInstalled?: boolean }).__deliveryInstalled) return;
  (manager as unknown as { __deliveryInstalled?: boolean }).__deliveryInstalled = true;

  const deliver = (content: string) => {
    void pi.sendMessage(
      { customType: "workflow-result", content, display: true },
      { triggerTurn: true, deliverAs: "followUp" },
    );
  };

  manager.on("complete", ({ runId }: { runId: string }) => {
    const run = manager.getRun(runId);
    // Only background/resumed runs are delivered: a foreground (sync) run already
    // returns its result inline as the tool result, so re-delivering would dup it.
    if (run?.background) deliver(deliverText(run));
  });
  manager.on("error", ({ runId, error }: { runId: string; error?: { message?: string } }) => {
    if (!manager.getRun(runId)?.background) return;
    deliver(`✗ Background workflow ${runId} failed: ${error?.message ?? "unknown error"}`);
  });
}

/**
 * Build the framed live panel. Returns [] when nothing is running so the widget
 * collapses. The frame is background-filled (see panel-box) so it stays readable
 * over a terminal wallpaper; `width` is the viewport width from Component.render.
 */
function renderPanel(manager: WorkflowManager, theme: Theme, width: number): string[] {
  // This runs in the TUI render timer: an uncaught throw (e.g. theme.fg on an
  // unregistered role) would crash Pi, so the whole build — not just framePanel —
  // degrades to an empty panel on failure.
  try {
    // Serve from the in-memory runs map (listActiveRuns) — NOT listRuns(), which
    // does readdirSync + a readFileSync per run file on every render and would block
    // the TUI event loop during a wide fan-out.
    const active = manager.listActiveRuns();
    if (!active.length) return [];
    const rows = active.map((r) => {
      const agents = r.snapshot.agents;
      const done = agents.filter((a) => a.status === "done").length;
      const icon = r.status === "paused" ? theme.fg("warning", "⏸") : theme.fg("accent", "◆");
      const phase = r.snapshot.currentPhase ? theme.fg("dim", ` · ${r.snapshot.currentPhase}`) : "";
      return `${icon} ${r.snapshot.name}  ${done}/${agents.length} agents${phase}`;
    });
    rows.push(theme.fg("dim", "run /workflows to open"));
    return framePanel(rows, theme, { title: `Workflows running (${active.length})`, maxWidth: width });
  } catch {
    return [];
  }
}

/**
 * Install the live "workflows running" panel below the editor. Re-rendered on
 * every manager event. Informational only — the user opens the navigator with
 * /workflows. (`_pi`/`_opts` are kept for signature stability.)
 */
export function installTaskPanel(
  _pi: ExtensionAPI,
  manager: WorkflowManager,
  ui: ExtensionUIContext,
  _opts: TaskPanelOptions = {},
): void {
  ui.setWidget(
    "workflow-tasks",
    (tui: TUI, theme: Theme) => {
      const onEvent = () => tui.requestRender();
      for (const ev of RUN_EVENTS) manager.on(ev, onEvent);
      // Purely informational: it lists running runs and re-renders on events. To
      // open the navigator, the user runs /workflows (the panel takes no input).
      const comp: Component & { dispose?(): void } = {
        render: (width: number) => profile("render:taskpanel", () => renderPanel(manager, theme, width)),
        invalidate: () => {},
        dispose: () => {
          for (const ev of RUN_EVENTS) manager.off(ev, onEvent);
        },
      };
      return comp;
    },
    { placement: "belowEditor" },
  );
}
