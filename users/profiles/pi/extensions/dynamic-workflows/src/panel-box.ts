/**
 * Panel framing for legibility over terminal background images / transparency.
 *
 * A border alone is not enough when the terminal has a wallpaper — the gaps
 * between glyphs still show through. So every line (border AND content) gets an
 * opaque background fill; the frame uses the theme's border colour. Width-aware
 * via pi-tui's ANSI-safe helpers, so existing per-token styling inside `lines`
 * is preserved.
 *
 * Defensive by design: `theme.bg`/`theme.fg` throw on color names a theme does
 * not define, and this runs inside the TUI render timer — an uncaught throw
 * there crashes Pi. So any styling failure falls back to the raw lines.
 */

import type { Theme } from "@earendil-works/pi-coding-agent";
import { truncateToWidth, visibleWidth } from "@earendil-works/pi-tui";

export interface FramePanelOptions {
  /** When set, the panel fills this exact viewport width. Omit to size to content. */
  width?: number;
  /** Upper bound when sizing to content (e.g. the viewport width). */
  maxWidth?: number;
  /** Optional title row, drawn bold/accent above a divider. */
  title?: string;
}

const PAD = 1; // spaces between the border and the content
// A background role that pi's Theme.bg actually registers (cardBg/pageBg/infoBg
// exist in theme JSON but are NOT exposed via Theme.bg). selectedBg is used by
// pi core itself, so every theme provides it.
const PANEL_BG = "selectedBg";

export function framePanel(lines: string[], theme: Theme, opts: FramePanelOptions = {}): string[] {
  try {
    const fill = (s: string) => theme.bg(PANEL_BG, s);
    const edge = (s: string) => theme.bg(PANEL_BG, theme.fg("border", s));

    const viewport = opts.width ?? opts.maxWidth ?? 80;
    const hardMax = Math.max(8, viewport - 2 - PAD * 2);
    const contentWidth = opts.width
      ? hardMax
      : Math.min(hardMax, Math.max(1, visibleWidth(opts.title ?? ""), ...lines.map(visibleWidth)));

    const inner = contentWidth + PAD * 2;
    const pad = " ".repeat(PAD);
    const row = (body: string) =>
      edge("│") + fill(pad + truncateToWidth(body, contentWidth, "…", true) + pad) + edge("│");

    const out = [edge(`╭${"─".repeat(inner)}╮`)];
    if (opts.title) {
      out.push(row(theme.bold(theme.fg("accent", opts.title))));
      out.push(edge(`├${"─".repeat(inner)}┤`));
    }
    for (const line of lines) out.push(row(line));
    out.push(edge(`╰${"─".repeat(inner)}╯`));
    return out;
  } catch {
    // Never let a render-time styling error take down the TUI.
    return lines;
  }
}
