/**
 * Interactive `/workflows` navigator, modeled on Claude Code's view:
 *
 *   runs ──enter──▶ phases ──enter──▶ agents ──enter──▶ agent detail
 *        ◀──esc───        ◀──esc────         ◀──esc────
 *
 * Keys: ↑/↓ (or j/k) select · enter/→ drill in · esc/← back (esc at top closes)
 *       p pause/resume · x stop · r restart · s save · q quit
 *
 * The state machine and line rendering are pure and unit-tested; the pi-tui
 * Component shell (openWorkflowNavigator) wires them to live manager events.
 */

import type { ExtensionAPI, ExtensionUIContext, Theme } from "@earendil-works/pi-coding-agent";
import type { Component, TUI } from "@earendil-works/pi-tui";
import { parseKey } from "@earendil-works/pi-tui";
import { framePanel } from "./panel-box.ts";
import { profile } from "./profiler.ts";
import type { WorkflowAgentSnapshot, WorkflowSnapshot } from "./display.ts";
import type { PersistedRunState } from "./run-persistence.ts";
import { registerSavedWorkflow } from "./saved-commands.ts";
import type { WorkflowManager } from "./workflow-manager.ts";
import type { WorkflowStorage } from "./workflow-saved.ts";

// Max cadence for the navigator's on-disk run-list refresh (listRuns = readdir +
// readFile-per-run). Bounds disk I/O regardless of manager-event volume.
const NAV_REFRESH_THROTTLE_MS = 200;

const STATUS_ICON: Record<string, string> = {
  pending: "·",
  queued: "·",
  running: "◆",
  paused: "⏸",
  completed: "✓",
  done: "✓",
  failed: "✗",
  error: "✗",
  aborted: "⊘",
  skipped: "⊘",
};

/** Minimal theme surface so rendering is testable without the real Theme class. */
export interface ThemeLike {
  fg(color: string, text: string): string;
  bold(text: string): string;
}

const PLAIN: ThemeLike = { fg: (_c, t) => t, bold: (t) => t };

export type ViewKind = "runs" | "phases" | "agents" | "detail";

interface RunRow {
  runId: string;
  name: string;
  status: string;
  done: number;
  total: number;
  tokens: number;
}
interface PhaseRow {
  title: string;
  done: number;
  total: number;
  tokens: number;
}
interface AgentRow {
  id: number;
  label: string;
  status: string;
  phase?: string;
  tokens?: number;
  model?: string;
}

/** Short, human-friendly model label: drop the provider prefix for display. */
function shortModel(model: string | undefined): string | undefined {
  if (!model) return undefined;
  const slash = model.indexOf("/");
  return slash > 0 ? model.slice(slash + 1) : model;
}

/** Reads run/phase/agent data from the manager, preferring live snapshots. */
export class NavigatorModel {
  // Cached on-disk run list. listRuns() does readdirSync + readFileSync-per-run,
  // so render must never call it; callers refresh() this on open and on a throttled
  // cadence. Live per-run contents are still overlaid from getRun() (in-memory) on
  // every render, so progress stays current between refreshes.
  private cachedRuns: PersistedRunState[] | null = null;

  constructor(private readonly manager: Pick<WorkflowManager, "listRuns" | "getRun">) {}

  /** Re-read the persisted run list from disk. Call on open + throttled, NOT per render. */
  refresh(): void {
    this.cachedRuns = this.manager.listRuns();
  }

  private persistedRuns(): PersistedRunState[] {
    if (this.cachedRuns === null) this.cachedRuns = this.manager.listRuns();
    return this.cachedRuns;
  }

  private snapshot(runId: string): { snapshot: WorkflowSnapshot; status: string } | undefined {
    const live = this.manager.getRun(runId);
    if (live) return { snapshot: live.snapshot, status: live.status };
    const p = this.persistedRuns().find((r) => r.runId === runId);
    if (!p) return undefined;
    return { snapshot: persistedToSnapshot(p), status: p.status };
  }

  runs(): RunRow[] {
    return this.persistedRuns().map((p) => {
      const live = this.manager.getRun(p.runId);
      const agents = (live?.snapshot.agents ?? p.agents) as WorkflowAgentSnapshot[];
      return {
        runId: p.runId,
        name: live?.snapshot.name ?? p.workflowName,
        status: live?.status ?? p.status,
        done: agents.filter((a) => a.status === "done").length,
        total: agents.length,
        tokens: (live?.snapshot.tokenUsage ?? p.tokenUsage)?.total ?? 0,
      };
    });
  }

  runName(runId: string): string {
    return this.snapshot(runId)?.snapshot.name ?? runId;
  }

  runStatus(runId: string): string {
    return this.snapshot(runId)?.status ?? "unknown";
  }

  phases(runId: string): PhaseRow[] {
    const snap = this.snapshot(runId)?.snapshot;
    if (!snap) return [];
    const order = snap.phases.length ? [...snap.phases] : [];
    const byPhase = new Map<string, AgentRow[]>();
    for (const a of snap.agents) {
      const key = a.phase ?? "(no phase)";
      if (!byPhase.has(key)) byPhase.set(key, []);
      byPhase.get(key)?.push(a);
      if (!order.includes(key)) order.push(key);
    }
    return order.map((title) => {
      const agents = byPhase.get(title) ?? [];
      return {
        title,
        done: agents.filter((a) => a.status === "done").length,
        total: agents.length,
        tokens: agents.reduce((n, a) => n + (a.tokens ?? 0), 0),
      };
    });
  }

  agents(runId: string, phase: string): AgentRow[] {
    const snap = this.snapshot(runId)?.snapshot;
    if (!snap) return [];
    return snap.agents
      .filter((a) => (a.phase ?? "(no phase)") === phase)
      .map((a) => ({ id: a.id, label: a.label, status: a.status, phase: a.phase, tokens: a.tokens, model: a.model }));
  }

  agentDetail(runId: string, agentId: number): WorkflowAgentSnapshot | undefined {
    return this.snapshot(runId)?.snapshot.agents.find((a) => a.id === agentId);
  }
}

function persistedToSnapshot(p: PersistedRunState): WorkflowSnapshot {
  return {
    name: p.workflowName,
    phases: p.phases,
    currentPhase: p.currentPhase,
    logs: p.logs,
    agents: p.agents.map((a) => ({
      id: a.id,
      label: a.label,
      phase: a.phase,
      prompt: a.prompt,
      status: a.status,
      resultPreview:
        a.result == null ? undefined : String(typeof a.result === "string" ? a.result : JSON.stringify(a.result)),
      error: a.error,
      model: a.model,
    })),
    agentCount: p.agents.length,
    runningCount: p.agents.filter((a) => a.status === "running").length,
    doneCount: p.agents.filter((a) => a.status === "done").length,
    errorCount: p.agents.filter((a) => a.status === "error").length,
    tokenUsage: p.tokenUsage ? { ...p.tokenUsage } : undefined,
    runId: p.runId,
  };
}

/** Navigation state machine: a stack of (view, cursor) frames plus detail scroll. */
export class NavigatorState {
  private stack: Array<{ kind: ViewKind; cursor: number; runId?: string; phase?: string; agentId?: number }> = [
    { kind: "runs", cursor: 0 },
  ];
  scroll = 0;

  private top() {
    return this.stack[this.stack.length - 1];
  }
  get kind(): ViewKind {
    return this.top().kind;
  }
  get cursor(): number {
    return this.top().cursor;
  }
  get runId(): string | undefined {
    return this.top().runId;
  }
  get phase(): string | undefined {
    return this.top().phase;
  }
  get agentId(): number | undefined {
    return this.top().agentId;
  }
  get depth(): number {
    return this.stack.length;
  }

  /** Clamp the cursor to [0, count). */
  clamp(count: number) {
    const t = this.top();
    t.cursor = count <= 0 ? 0 : Math.max(0, Math.min(t.cursor, count - 1));
  }

  move(delta: number, count: number) {
    if (this.kind === "detail") {
      this.scroll = Math.max(0, this.scroll + delta);
      return;
    }
    if (count <= 0) return;
    const t = this.top();
    t.cursor = (t.cursor + delta + count) % count;
  }

  /** Drill into the selected item. Returns true if the view changed. */
  drill(model: NavigatorModel): boolean {
    const t = this.top();
    if (t.kind === "runs") {
      const runs = model.runs();
      const run = runs[t.cursor];
      if (!run) return false;
      this.stack.push({ kind: "phases", cursor: 0, runId: run.runId });
      return true;
    }
    if (t.kind === "phases" && t.runId) {
      const phases = model.phases(t.runId);
      const ph = phases[t.cursor];
      if (!ph) return false;
      this.stack.push({ kind: "agents", cursor: 0, runId: t.runId, phase: ph.title });
      return true;
    }
    if (t.kind === "agents" && t.runId && t.phase) {
      const agents = model.agents(t.runId, t.phase);
      const ag = agents[t.cursor];
      if (!ag) return false;
      this.scroll = 0;
      this.stack.push({ kind: "detail", cursor: 0, runId: t.runId, phase: t.phase, agentId: ag.id });
      return true;
    }
    return false;
  }

  /** Pop one level. Returns false when already at the top (caller should close). */
  back(): boolean {
    if (this.stack.length <= 1) return false;
    this.stack.pop();
    this.scroll = 0;
    return true;
  }

  /** The runId the current view acts on (for pause/stop/save). */
  activeRunId(model: NavigatorModel): string | undefined {
    if (this.runId) return this.runId;
    if (this.kind === "runs") return model.runs()[this.cursor]?.runId;
    return undefined;
  }
}

function pad(n: number): string {
  return n.toLocaleString();
}

function fmtTokens(t: number): string {
  return t > 0 ? `${pad(t)} tok` : "";
}

/** Build the lines for the current view. Pure: depends only on state + model + theme. */
export function renderNavigator(
  state: NavigatorState,
  model: NavigatorModel,
  width: number,
  theme: ThemeLike = PLAIN,
): string[] {
  const lines: string[] = [];
  const sel = (i: number, text: string) =>
    i === state.cursor ? theme.fg("accent", theme.bold(`❯ ${text}`)) : `  ${text}`;
  const dim = (t: string) => theme.fg("dim", t);

  if (state.kind === "runs") {
    const runs = model.runs();
    state.clamp(runs.length);
    lines.push(theme.bold("Workflows"));
    if (!runs.length) lines.push(dim("  No runs yet. Start one with a background workflow."));
    runs.forEach((r, i) => {
      const icon = STATUS_ICON[r.status] ?? "?";
      const meta = [`${r.done}/${r.total}`, fmtTokens(r.tokens)].filter(Boolean).join(" · ");
      lines.push(sel(i, `${icon} ${r.name}  ${dim(`${r.runId} · ${r.status} · ${meta}`)}`));
    });
  } else if (state.kind === "phases" && state.runId) {
    const phases = model.phases(state.runId);
    state.clamp(phases.length);
    lines.push(theme.bold(model.runName(state.runId)) + dim(`  (${model.runStatus(state.runId)})`));
    phases.forEach((p, i) => {
      const meta = [`${p.done}/${p.total} agents`, fmtTokens(p.tokens)].filter(Boolean).join(" · ");
      lines.push(sel(i, `${p.title}  ${dim(meta)}`));
    });
  } else if (state.kind === "agents" && state.runId && state.phase) {
    const agents = model.agents(state.runId, state.phase);
    state.clamp(agents.length);
    lines.push(theme.bold(`${model.runName(state.runId)} › ${state.phase}`));
    agents.forEach((a, i) => {
      const icon = STATUS_ICON[a.status] ?? "?";
      const mdl = shortModel(a.model);
      const meta = [mdl, a.tokens ? fmtTokens(a.tokens) : undefined].filter(Boolean).join(" · ");
      lines.push(sel(i, `${icon} ${a.label}${meta ? dim(`  ${meta}`) : ""}`));
    });
  } else if (state.kind === "detail" && state.runId && state.agentId != null) {
    const a = model.agentDetail(state.runId, state.agentId);
    lines.push(theme.bold(a ? a.label : "agent"));
    if (a) {
      const body: string[] = [];
      body.push(dim("Status: ") + (a.status ?? ""));
      if (a.model) body.push(dim("Model: ") + (shortModel(a.model) ?? ""));
      if (a.error) body.push(dim("Error: ") + a.error);
      body.push("", dim("Prompt:"));
      body.push(...wrap(a.prompt ?? "", width));
      body.push("", dim("Result:"));
      body.push(...wrap(a.resultPreview ?? "(none)", width));
      // Scrollable region.
      const maxScroll = Math.max(0, body.length - 1);
      state.scroll = Math.min(state.scroll, maxScroll);
      lines.push(...body.slice(state.scroll));
    }
  }

  lines.push("");
  lines.push(footerHint(state, theme));

  // Frame the navigator in a background-filled box so it stays legible over a
  // terminal wallpaper. Only when the full Theme (with bg fill) is present — the
  // PLAIN fallback used in tests has no `bg`, so it returns the raw lines.
  const full = theme as Partial<Theme>;
  return typeof full.bg === "function" ? framePanel(lines, full as Theme, { width }) : lines;
}

function footerHint(state: NavigatorState, theme: ThemeLike): string {
  const parts =
    state.kind === "detail"
      ? ["j/k scroll", "esc back"]
      : ["↑/↓ select", "enter open", "esc back", "p pause", "x stop", "r restart", "s save", "q quit"];
  return theme.fg("dim", parts.join(" · "));
}

function wrap(text: string, width: number): string[] {
  const w = Math.max(20, width - 2);
  const out: string[] = [];
  for (const para of String(text).split("\n")) {
    if (para.length <= w) {
      out.push(para);
      continue;
    }
    let rest = para;
    while (rest.length > w) {
      out.push(rest.slice(0, w));
      rest = rest.slice(w);
    }
    if (rest) out.push(rest);
  }
  return out;
}

/** What a key press should do. Pure mapping from a parsed key id to an action. */
export type NavAction =
  | { type: "move"; delta: number }
  | { type: "drill" }
  | { type: "back" }
  | { type: "close" }
  | { type: "pause" }
  | { type: "stop" }
  | { type: "restart" }
  | { type: "save" }
  | { type: "none" };

export function keyToAction(keyId: string | undefined, kind: ViewKind): NavAction {
  switch (keyId) {
    case "up":
      return { type: "move", delta: -1 };
    case "down":
      return { type: "move", delta: 1 };
    case "k":
      return { type: "move", delta: -1 };
    case "j":
      return { type: "move", delta: 1 };
    case "enter":
    case "return":
    case "right":
      return kind === "detail" ? { type: "none" } : { type: "drill" };
    case "escape":
    case "esc":
    case "left":
      return { type: "back" };
    case "q":
      return { type: "close" };
    case "p":
      return { type: "pause" };
    case "x":
      return { type: "stop" };
    case "r":
      return { type: "restart" };
    case "s":
      return { type: "save" };
    default:
      return { type: "none" };
  }
}

function currentCount(state: NavigatorState, model: NavigatorModel): number {
  if (state.kind === "runs") return model.runs().length;
  if (state.kind === "phases" && state.runId) return model.phases(state.runId).length;
  if (state.kind === "agents" && state.runId && state.phase) return model.agents(state.runId, state.phase).length;
  return 0;
}

export interface NavigatorOptions {
  storage?: WorkflowStorage;
  cwd?: string;
}

/**
 * Open the interactive `/workflows` navigator as a focused overlay. Resolves when
 * the user closes it (esc at the top level, or `q`).
 */
export function openWorkflowNavigator(
  pi: ExtensionAPI,
  manager: WorkflowManager,
  ui: ExtensionUIContext,
  opts: NavigatorOptions = {},
): Promise<void> {
  const model = new NavigatorModel(manager);
  const state = new NavigatorState();

  return ui.custom<void>(
    (tui: TUI, theme: Theme, _keybindings, done: (r: void) => void) => {
      const rerender = () => tui.requestRender();
      const events = ["agentStart", "agentEnd", "phase", "log", "complete", "error", "stopped", "paused", "resumed"];
      // Coalesce disk refreshes: events burst (log/agentStart per agent during a
      // fan-out). Re-read the run list at most once per window — renders in between
      // use the cache + in-memory getRun overlay. We still rerender() immediately on
      // each event (cheap, no disk) so live progress shows without waiting.
      let refreshTimer: ReturnType<typeof setTimeout> | null = null;
      const scheduleRefresh = () => {
        if (refreshTimer) return;
        refreshTimer = setTimeout(() => {
          refreshTimer = null;
          model.refresh();
          rerender();
        }, NAV_REFRESH_THROTTLE_MS);
        if (typeof (refreshTimer as { unref?: () => void }).unref === "function") {
          (refreshTimer as { unref: () => void }).unref();
        }
      };
      model.refresh(); // initial on-open snapshot
      const onEvent = () => {
        rerender();
        scheduleRefresh();
      };
      for (const ev of events) manager.on(ev, onEvent);
      const cleanup = () => {
        for (const ev of events) manager.off(ev, onEvent);
        if (refreshTimer) {
          clearTimeout(refreshTimer);
          refreshTimer = null;
        }
      };

      const act = (data: string) => {
        const action = keyToAction(parseKey(data), state.kind);
        switch (action.type) {
          case "move":
            state.move(action.delta, currentCount(state, model));
            break;
          case "drill":
            state.drill(model);
            break;
          case "back":
            if (!state.back()) {
              cleanup();
              done();
            }
            break;
          case "close":
            cleanup();
            done();
            return;
          case "pause": {
            const id = state.activeRunId(model);
            if (id) ui.notify(manager.pause(id) ? `Paused ${id}` : `Cannot pause ${id}`, "info");
            break;
          }
          case "stop": {
            const id = state.activeRunId(model);
            if (id) ui.notify(manager.stop(id) ? `Stopped ${id}` : `Cannot stop ${id}`, "info");
            break;
          }
          case "restart": {
            // Restart re-runs the whole workflow from scratch as a fresh
            // background run (per-agent restart isn't meaningful — agents are
            // driven by the script). The new run auto-delivers when it finishes.
            const id = state.activeRunId(model);
            const run = id ? manager.listRuns().find((r) => r.runId === id) : undefined;
            if (!run?.script) {
              ui.notify(id ? `Cannot restart ${id} (no script saved)` : "No run selected to restart", "warning");
              break;
            }
            const { runId: newId } = manager.startInBackground(run.script, run.args);
            ui.notify(`Restarted ${run.workflowName || "workflow"} as ${newId}`, "info");
            break;
          }
          case "save": {
            const id = state.activeRunId(model);
            const run = id ? manager.listRuns().find((r) => r.runId === id) : undefined;
            if (!run?.script) {
              ui.notify("No saved run script to save", "warning");
            } else if (!opts.storage) {
              ui.notify("Saving is not available (no storage)", "error");
            } else {
              const name = run.workflowName || "workflow";
              // storage.save -> assertSafeName throws for names with spaces/special
              // chars (a workflow's meta.name only has to be non-empty to validate).
              // act() is the synchronous input handler, so an escaping throw would
              // crash the navigator — catch it and notify instead.
              try {
                const saved = opts.storage.save({
                  name,
                  description: run.workflowName,
                  script: run.script,
                  location: "project",
                });
                registerSavedWorkflow(pi, opts.cwd ?? process.cwd(), saved);
                ui.notify(`Saved /${name}`, "info");
              } catch (error) {
                ui.notify(`Cannot save workflow: ${error instanceof Error ? error.message : error}`, "error");
              }
            }
            break;
          }
          default:
            return;
        }
        rerender();
      };

      const component: Component & { dispose?(): void } = {
        // Guard the render: it runs in the TUI render timer, where an uncaught
        // throw (e.g. theme.fg on an unregistered role, or a model read) crashes
        // Pi. renderNavigator stays pure; the catch lives at the call site and
        // falls back to a plain (un-themed) line so the overlay can't take Pi down.
        render: (width: number) =>
          profile("render:navigator", () => {
            try {
              return renderNavigator(state, model, width, theme);
            } catch {
              return ["(workflow navigator failed to render — press esc/q to close)"];
            }
          }),
        handleInput: (data: string) => act(data),
        invalidate: () => {},
        dispose: () => cleanup(),
      };
      return component;
    },
    { overlay: true },
  );
}
