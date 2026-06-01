/**
 * Scrollable plan-review overlay.
 *
 * Pi renders a `ui.select` title (and `ui.notify` body) as a static, clipped
 * block — a plan taller than the terminal can't be scrolled and pushes the
 * options off-screen. This presents the plan in a focused `ui.custom` overlay
 * that scrolls the plan body while keeping the action list pinned and visible.
 *
 * Keys: ↑/↓ or j/k scroll · PageUp/PageDown (Ctrl-U/Ctrl-D, space) page ·
 *       g/Home top · G/End bottom · Tab/←→ (or 1–9) move action ·
 *       Enter confirm · Esc/q cancel.
 *
 * The state, line rendering, and key mapping are pure (no pi-tui imports) so
 * they stay testable; `showPlanReview` is the thin Component shell that wires
 * them to the overlay. Modeled on dynamic-workflows' openWorkflowNavigator.
 */

import type { ExtensionUIContext } from "@earendil-works/pi-coding-agent";
import type { Component, TUI } from "@earendil-works/pi-tui";
import { parseKey, truncateToWidth, visibleWidth } from "@earendil-works/pi-tui";

/**
 * Minimal theme surface (matches what plan-mode/index.ts already relies on).
 * `bg` is optional: the real Theme provides it, the PLAIN test stand-in doesn't,
 * so the border falls back to an unfilled frame without it.
 */
export interface ThemeLike {
  fg(color: string, text: string): string;
  bold(text: string): string;
  bg?(role: string, text: string): string;
}

const PLAIN: ThemeLike = { fg: (_c, t) => t, bold: (t) => t };

// Horizontal padding between the border and the content.
const FRAME_PAD = 1;
// The only background role pi's Theme.bg reliably registers (cardBg/pageBg exist
// in theme JSON but aren't exposed via Theme.bg). selectedBg is used by pi core,
// so every theme provides it. See reference_pi_theme_bg_roles.
const FRAME_BG = "selectedBg";

/** Sentinel line: framePlanPanel renders it as a connecting `├───┤` divider. */
export const PANEL_DIVIDER = "\x00plan-divider";

/**
 * Wrap `lines` in a rounded border exactly `width` columns wide, with the title
 * inline in the top edge. Content rows are right-padded (and bg-filled when the
 * theme supports it) so the panel stays solid over a terminal wallpaper. A
 * PANEL_DIVIDER entry becomes a side-connected `├───┤` rule; any entry that
 * contains newlines is split so it can't escape the frame.
 * Defensive: any styling failure falls back to the raw lines — this runs in the
 * TUI render timer, where an uncaught throw crashes pi.
 */
export function framePlanPanel(lines: string[], theme: ThemeLike, width: number, title: string): string[] {
  try {
    const fill = theme.bg ? (s: string) => theme.bg!(FRAME_BG, s) : (s: string) => s;
    const edge = (s: string) => fill(theme.fg("border", s));
    const inner = Math.max(8, width - 2); // span between the two vertical edges
    const contentW = inner - FRAME_PAD * 2;
    const pad = " ".repeat(FRAME_PAD);
    const row = (body: string) =>
      edge("│") + fill(pad + truncateToWidth(body, contentW, "…", true) + pad) + edge("│");

    // Truncate an over-long title so the top edge can't overflow `width`.
    const t = truncateToWidth(title, Math.max(0, width - 6), "…");
    const dashes = Math.max(1, width - 5 - visibleWidth(t)); // ╭(1)─( )(2) t ( )(1) ╮(1)
    const top = edge("╭─ ") + fill(theme.bold(theme.fg("accent", t))) + edge(` ${"─".repeat(dashes)}╮`);
    const bottom = edge(`╰${"─".repeat(inner)}╯`);
    const divider = edge(`├${"─".repeat(inner)}┤`);

    const body = lines.flatMap((line) =>
      line === PANEL_DIVIDER ? [divider] : line.split("\n").map(row),
    );
    return [top, ...body, bottom];
  } catch {
    return lines;
  }
}

export interface PlanReviewState {
  scroll: number;
  actionCursor: number;
  /** Captured each render cycle via OverlayOptions.visible (render() gets width only). */
  termHeight: number;
  /** Plan-body rows shown by the last render — the page-scroll step. */
  lastViewport: number;
}

export function createPlanReviewState(): PlanReviewState {
  return { scroll: 0, actionCursor: 0, termHeight: 24, lastViewport: 0 };
}

/** Wrap text to the viewport width, preserving blank lines and hard newlines. */
export function wrapPlan(plan: string, width: number): string[] {
  const w = Math.max(20, width - 2);
  const out: string[] = [];
  for (const para of String(plan).replace(/\t/g, "  ").split("\n")) {
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

/**
 * How many plan-body rows fit, given the captured terminal height and the count
 * of reserved (non-body) rows: borders, summary lines, indicators, divider,
 * actions, and footer. Computed by the caller so it adapts to a multi-line
 * summary or a varying number of actions.
 */
export function planViewportRows(termHeight: number, reservedRows: number): number {
  const budget = Math.max(8, Math.floor(termHeight * 0.85));
  return Math.max(3, budget - reservedRows);
}

export function maxScrollFor(bodyLen: number, viewportRows: number): number {
  return Math.max(0, bodyLen - viewportRows);
}

export interface PlanReviewView {
  header: string;
  /** Optional second header line (e.g. plan-file summary). */
  subheader?: string;
  actions: string[];
}

/** Pure: build the overlay's lines for the current scroll/cursor state. */
export function renderPlanReview(
  state: PlanReviewState,
  bodyLines: string[],
  view: PlanReviewView,
  width: number,
  theme: ThemeLike = PLAIN,
): string[] {
  const dim = (t: string) => theme.fg("dim", t);

  // Plan-file metadata (a multi-line string) above the plan body.
  const head: string[] = [];
  if (view.subheader) for (const line of view.subheader.split("\n")) head.push(dim(line));
  head.push("");

  // A divider rule separates the plan from the approval actions + footer hint.
  const tail: string[] = [PANEL_DIVIDER];
  view.actions.forEach((label, i) => {
    tail.push(i === state.actionCursor ? theme.fg("accent", theme.bold(`❯ ${label}`)) : `  ${label}`);
  });
  tail.push(dim("↑/↓ scroll · PgUp/PgDn page · g/G top/bottom · Tab/1-9 action · enter select · esc cancel"));

  // Reserved = head + the two scroll-indicator rows + tail + the two border rows.
  const reserved = head.length + 2 + tail.length + 2;
  const viewport = planViewportRows(state.termHeight, reserved);
  state.lastViewport = viewport;

  const maxScroll = maxScrollFor(bodyLines.length, viewport);
  state.scroll = Math.max(0, Math.min(state.scroll, maxScroll));
  const above = state.scroll;
  const windowLines = bodyLines.slice(state.scroll, state.scroll + viewport);
  const below = Math.max(0, bodyLines.length - (state.scroll + viewport));

  const inner = [
    ...head,
    above > 0 ? dim(`↑ ${above} more`) : "",
    ...windowLines,
    below > 0 ? dim(`↓ ${below} more`) : "",
    ...tail,
  ];

  // The title lives in the border's top edge; the frame sizes rows to `width`.
  return framePlanPanel(inner, theme, width, view.header);
}

export type PlanReviewAction =
  | { type: "scroll"; delta: number }
  | { type: "page"; delta: number }
  | { type: "top" }
  | { type: "bottom" }
  | { type: "moveAction"; delta: number }
  | { type: "selectAction"; index: number }
  | { type: "confirm" }
  | { type: "cancel" }
  | { type: "none" };

/** Pure: map a parsed key id to a plan-review action. */
export function keyToPlanAction(keyId: string | undefined): PlanReviewAction {
  switch (keyId) {
    case "up":
    case "k":
      return { type: "scroll", delta: -1 };
    case "down":
    case "j":
      return { type: "scroll", delta: 1 };
    case "pageUp":
    case "ctrl+u":
      return { type: "page", delta: -1 };
    case "pageDown":
    case "ctrl+d":
    case "space":
      return { type: "page", delta: 1 };
    case "g":
    case "home":
      return { type: "top" };
    case "G":
    case "shift+g":
    case "end":
      return { type: "bottom" };
    case "tab":
    case "right":
      return { type: "moveAction", delta: 1 };
    case "shift+tab":
    case "left":
      return { type: "moveAction", delta: -1 };
    case "enter":
    case "return":
      return { type: "confirm" };
    case "escape":
    case "esc":
    case "q":
      return { type: "cancel" };
    default:
      if (keyId && /^[1-9]$/.test(keyId)) return { type: "selectAction", index: Number(keyId) - 1 };
      return { type: "none" };
  }
}

export interface PlanReviewOptions {
  /** The plan body to display (already read from disk — do no I/O in render). */
  plan: string;
  /** Header title (e.g. the plan title). */
  title: string;
  /** Optional subheader line (e.g. plan-file summary). */
  summary?: string;
  /** Selectable actions; the resolved value is the chosen label, or undefined on cancel. */
  actions: string[];
}

/**
 * Show the scrollable plan-review overlay. Resolves to the chosen action label,
 * or undefined when cancelled (esc/q). Requires an interactive UI.
 */
export function showPlanReview(ui: ExtensionUIContext, opts: PlanReviewOptions): Promise<string | undefined> {
  const state = createPlanReviewState();
  const actions = opts.actions.length ? opts.actions : ["Close"];
  const view: PlanReviewView = { header: `📋 ${opts.title}`, subheader: opts.summary, actions };

  return ui.custom<string | undefined>(
    (tui: TUI, theme, _keybindings, done) => {
      let bodyLines: string[] = [];
      let lastWidth = -1;

      const pageDelta = () => Math.max(1, state.lastViewport - 1);

      const act = (data: string) => {
        const action = keyToPlanAction(parseKey(data));
        switch (action.type) {
          case "scroll":
            state.scroll += action.delta;
            break;
          case "page":
            state.scroll += action.delta * pageDelta();
            break;
          case "top":
            state.scroll = 0;
            break;
          case "bottom":
            // Clamped against maxScroll in render; a large value pins to bottom.
            state.scroll = bodyLines.length;
            break;
          case "moveAction":
            state.actionCursor = (state.actionCursor + action.delta + actions.length) % actions.length;
            break;
          case "selectAction":
            if (action.index < actions.length) state.actionCursor = action.index;
            break;
          case "confirm":
            done(actions[state.actionCursor]);
            return;
          case "cancel":
            done(undefined);
            return;
          default:
            return;
        }
        if (state.scroll < 0) state.scroll = 0;
        tui.requestRender();
      };

      const component: Component = {
        render: (width: number) => {
          if (width !== lastWidth) {
            // Frame eats 2 edge cols + 2 padding cols; wrapPlan keeps its own
            // gutter, so width-2 yields lines that fit the framed content width.
            bodyLines = wrapPlan(opts.plan, width - 2);
            lastWidth = width;
          }
          return renderPlanReview(state, bodyLines, view, width, theme);
        },
        handleInput: (data: string) => act(data),
        invalidate: () => {
          lastWidth = -1;
        },
      };
      return component;
    },
    {
      overlay: true,
      overlayOptions: {
        width: "85%",
        maxHeight: "85%",
        anchor: "center",
        visible: (_termWidth: number, termHeight: number) => {
          state.termHeight = termHeight;
          return true;
        },
      },
    },
  );
}
