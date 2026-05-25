/**
 * Themed segment renderers for the footer extension.
 */

import type { Theme, ThemeColor } from "@earendil-works/pi-coding-agent";
import { truncateToWidth } from "@earendil-works/pi-tui";
import { formatTokens, formatCost, formatModelDisplay } from "./format.ts";

// ── Types ───────────────────────────────────────────────────

export type VcsType = "jj" | "git";

export interface VcsInfo {
  type: VcsType;
  /** Branch name (jj bookmark or git branch). */
  branch: string;
  /** jj change ID (short). */
  changeId?: string;
  /** jj revset (@ or @-). */
  revset?: string;
  added: number;
  deleted: number;
  hasConflict?: boolean;
}

// ── Thinking-level maps ─────────────────────────────────────

const THINKING_LABELS: Record<string, string> = {
  off: "off",
  minimal: "min",
  low: "low",
  medium: "med",
  high: "high",
  xhigh: "xhi",
};

const THINKING_COLORS: Record<string, ThemeColor> = {
  off: "dim",
  minimal: "muted",
  low: "accent",
  medium: "accent",
  high: "warning",
  xhigh: "error",
};

// ── Segment renderers ───────────────────────────────────────

/**
 * Render model segment.
 * @param provider - Separate provider (from ctx.model?.provider) when id lacks
 *   a "provider/" prefix.
 */
export function renderModel(
  theme: Theme,
  modelId: string | undefined,
  provider?: string,
): string | null {
  if (!modelId) return null;
  const display = formatModelDisplay(modelId, provider);
  if (!display) return null;
  return theme.fg("text", display);
}

/** Render thinking-level segment. Returns null for empty/undefined level. */
export function renderThinking(
  theme: Theme,
  level: string | undefined,
): string | null {
  if (!level) return null;
  const label = THINKING_LABELS[level] ?? level;
  const color = THINKING_COLORS[level] ?? "muted";
  return `${theme.fg(color, "think")} ${theme.fg(color, label)}`;
}

/** Render VCS segment (jj or git). Returns null when info is null. */
export function renderVcs(theme: Theme, info: VcsInfo | null): string | null {
  if (!info) return null;

  const { type, branch, changeId, revset, added, deleted, hasConflict } = info;
  const icon = type === "jj" ? "jj" : "git";

  // Build the branch/bookmark display
  let branchDisplay: string;
  if (type === "jj" && changeId) {
    const rev = revset ?? "@";
    branchDisplay = `${branch} ${rev} ${changeId.slice(0, 8)}`;
  } else {
    branchDisplay = truncateToWidth(branch, 20);
  }

  let result = `${theme.fg("accent", icon)} ${theme.fg("accent", branchDisplay)}`;

  // Diff stats
  if (added > 0 || deleted > 0) {
    const parts: string[] = [];
    if (added > 0) parts.push(theme.fg("success", `+${added}`));
    if (deleted > 0) parts.push(theme.fg("error", `-${deleted}`));
    result += ` ${parts.join(" ")}`;
  } else {
    result += ` ${theme.fg("dim", "clean")}`;
  }

  if (hasConflict) {
    result += ` ${theme.fg("error", "conflicts")}`;
  }

  return result;
}

/** Render token-count segment. Returns null when total is 0. */
export function renderTokens(theme: Theme, totalTokens: number): string | null {
  if (totalTokens === 0) return null;
  return `tok ${theme.fg("text", formatTokens(totalTokens))}`;
}

/** Render cost segment — just the dollar amount, no label. Returns null when 0. */
export function renderCost(theme: Theme, costUsd: number): string | null {
  if (costUsd === 0) return null;
  return theme.fg("text", formatCost(costUsd));
}

/**
 * Render provider + context-usage segment.
 * Shows e.g. "DeepSeek 45k/128k" with color-coded percentage.
 * Falls back to "Context" label when no provider is known.
 */
export function renderProviderContext(
  theme: Theme,
  providerLabel: string | undefined,
  used: number | null,
  total: number,
): string | null {
  if (total <= 0) return null;

  const tokens = used === null
    ? theme.fg("muted", "?")
    : (() => {
        const percent = Math.round((used / total) * 100);
        const color: ThemeColor =
          percent > 80 ? "error" : percent > 60 ? "warning" : "text";
        return theme.fg(color, formatTokens(used));
      })();

  const label = providerLabel ?? "Context";
  return `${theme.fg("muted", label)} ${tokens}/${theme.fg("text", formatTokens(total))}`;
}
