/**
 * Footer extension for Pi.
 *
 * Replaces the built-in footer with a custom layout:
 *   Left:  MODEL | think LEVEL | VCS_BRANCH +add -del
 *   Right: tok TOKENS | $COST | PROVIDER used/total
 *
 * Supports jj (Jujutsu) and git VCS backends (auto-detected).
 */

import { spawnSync } from "node:child_process";
import type { AgentMessage } from "@earendil-works/pi-agent-core";
import type {
  ExtensionAPI,
  ExtensionContext,
  ReadonlyFooterDataProvider,
  Theme,
} from "@earendil-works/pi-coding-agent";
import { truncateToWidth, visibleWidth } from "@earendil-works/pi-tui";
import {
  renderCost,
  renderModel,
  renderProviderContext,
  renderThinking,
  renderTokens,
  renderVcs,
  type VcsInfo,
} from "./segments.ts";

// ── Constants ───────────────────────────────────────────────

const JJ_TIMEOUT_MS = 1_500;
const GIT_TIMEOUT_MS = 2_000;
const VCS_CACHE_TTL_MS = 2_000;

// ── Types ───────────────────────────────────────────────────

interface UsageTotals {
  input: number;
  output: number;
  cost: number;
}

// ── Module-level cache ──────────────────────────────────────

let cachedVcsInfo: VcsInfo | null = null;
let lastVcsRefresh = 0;

// ── Usage collection ────────────────────────────────────────

/** Collect cumulative token usage and cost from session messages. */
function collectUsage(ctx: ExtensionContext): UsageTotals {
  const totals: UsageTotals = { input: 0, output: 0, cost: 0 };
  try {
    const branch = ctx.sessionManager.getBranch();
    if (!branch) return totals;

    for (const entry of branch) {
      if (entry.type !== "message") continue;
      const msg = entry.message as AgentMessage & {
        usage?: { input?: number; output?: number; cost?: { total?: number } };
      };
      if (msg.role !== "assistant") continue;
      const usage = msg.usage;
      if (!usage) continue;
      totals.input += usage.input ?? 0;
      totals.output += usage.output ?? 0;
      totals.cost += usage.cost?.total ?? 0;
    }
  } catch {
    // Defensive – session iteration may fail mid-compaction
  }
  return totals;
}

// ── VCS helpers ─────────────────────────────────────────────

interface DiffStat {
  files: number;
  insertions: number;
  deletions: number;
}

function parseDiffStat(raw: string): DiffStat {
  const summary = raw.trim().split("\n").at(-1) ?? "";
  const files = Number(summary.match(/(\d+) files? changed/)?.[1] ?? 0);
  const insertions = Number(summary.match(/(\d+) insertions?\(\+\)/)?.[1] ?? 0);
  const deletions = Number(summary.match(/(\d+) deletions?\(-\)/)?.[1] ?? 0);
  return { files, insertions, deletions };
}

/** Detect whether cwd is inside a jj repository. */
function isJjRepo(cwd: string): boolean {
  try {
    const result = spawnSync("jj", ["root"], {
      cwd,
      timeout: JJ_TIMEOUT_MS,
      stdio: ["ignore", "pipe", "ignore"],
    });
    return result.status === 0 && (result.stdout?.toString() ?? "").trim().length > 0;
  } catch {
    return false;
  }
}

/** Read jj VCS info synchronously. Returns null when not in a jj repo. */
function readJjInfoSync(cwd: string): VcsInfo | null {
  if (!isJjRepo(cwd)) return null;

  const runJj = (args: string[]): string => {
    try {
      const result = spawnSync("jj", args, {
        cwd,
        timeout: JJ_TIMEOUT_MS,
        stdio: ["ignore", "pipe", "ignore"],
      });
      return result.status === 0 ? (result.stdout?.toString() ?? "") : "";
    } catch {
      return "";
    }
  };

  // Check if current commit is empty
  const emptyText = runJj([
    "log", "-r", "@", "--no-graph", "-T", 'if(empty, "empty", "nonempty")',
  ]);
  const currentIsEmpty = emptyText.trim() === "empty";
  const revset: "@" | "@-" = currentIsEmpty ? "@-" : "@";

  // Get revision info
  const logOutput = runJj([
    "log", "-r", revset, "--no-graph", "-T",
    'change_id.short() ++ "\\n" ++ commit_id.short() ++ "\\n" ++ description.first_line() ++ "\\n" ++ bookmarks.join(" ") ++ "\\n"',
  ]);
  if (!logOutput) return null;

  const [changeId = "?", _commitId = "?", _description = "", bookmarkLine = ""] = logOutput.split("\n");

  // Check for conflicts
  const conflictText = runJj([
    "log", "-r", `conflicts() & ${revset}`, "--no-graph", "-T", "change_id.short()",
  ]);
  const hasConflict = conflictText.trim().length > 0;

  // Get diff stat
  const diffOutput = runJj(["diff", "--stat"]);
  const diff = parseDiffStat(diffOutput);

  const bookmarks = bookmarkLine.trim().split(/\s+/).filter(Boolean);
  const branch = bookmarks.length > 0 ? bookmarks[0] : changeId.slice(0, 8);

  return {
    type: "jj",
    branch,
    changeId: changeId.trim() || "?",
    revset,
    added: diff.insertions,
    deleted: diff.deletions,
    hasConflict,
  };
}

/** Read git VCS info synchronously via git branch + diff. */
function readGitInfoSync(cwd: string, footerData: ReadonlyFooterDataProvider): VcsInfo | null {
  const branch = footerData.getGitBranch();
  if (!branch) return null;

  const runGit = (args: string[]): string => {
    try {
      const result = spawnSync("git", args, {
        cwd,
        timeout: GIT_TIMEOUT_MS,
        stdio: ["ignore", "pipe", "ignore"],
      });
      return result.status === 0 ? (result.stdout?.toString() ?? "") : "";
    } catch {
      return "";
    }
  };

  // Parse diff --numstat for added/deleted
  const numstat = runGit(["diff", "--numstat", "--no-renames", "HEAD", "--"]);
  if (!numstat.trim()) {
    // Try staged + unstaged separately
    const staged = runGit(["diff", "--cached", "--numstat", "--no-renames", "--"]);
    const unstaged = runGit(["diff", "--numstat", "--no-renames", "--"]);
    const parseNumstat = (output: string): { added: number; deleted: number } => {
      let added = 0;
      let deleted = 0;
      for (const line of output.split("\n")) {
        const trimmed = line.trim();
        if (!trimmed) continue;
        const [a, d] = trimmed.split(/\s+/, 3);
        added += Number.parseInt(a ?? "0", 10) || 0;
        deleted += Number.parseInt(d ?? "0", 10) || 0;
      }
      return { added, deleted };
    };
    const s = parseNumstat(staged);
    const u = parseNumstat(unstaged);
    return {
      type: "git",
      branch,
      added: s.added + u.added,
      deleted: s.deleted + u.deleted,
    };
  }

  let added = 0;
  let deleted = 0;
  for (const line of numstat.split("\n")) {
    const trimmed = line.trim();
    if (!trimmed) continue;
    const [a, d] = trimmed.split(/\s+/, 3);
    added += Number.parseInt(a ?? "0", 10) || 0;
    deleted += Number.parseInt(d ?? "0", 10) || 0;
  }

  return {
    type: "git",
    branch,
    added,
    deleted,
  };
}

/** Refresh cached VCS info. */
function refreshVcs(cwd: string, footerData: ReadonlyFooterDataProvider): void {
  const now = Date.now();
  if (now - lastVcsRefresh < VCS_CACHE_TTL_MS && cachedVcsInfo !== undefined) return;

  // Try jj first, fall back to git
  cachedVcsInfo = readJjInfoSync(cwd) ?? readGitInfoSync(cwd, footerData);
  lastVcsRefresh = now;
}

// ── Provider-label helper ───────────────────────────────────

const KNOWN_PROVIDER_LABELS: Record<string, string> = {
  anthropic: "Anthropic",
  openai: "OpenAI",
  "openai-codex": "OpenAI Codex",
  google: "Google",
  deepseek: "DeepSeek",
  "opencode-go": "OpenCodeGo",
  xai: "xAI",
  groq: "Groq",
  openrouter: "OpenRouter",
  mistralai: "MistralAI",
};

/** Resolve a provider name to a short display label. */
function providerLabel(provider: string | undefined): string | undefined {
  if (!provider) return undefined;
  return KNOWN_PROVIDER_LABELS[provider] ?? provider;
}

// ── Footer line builder ─────────────────────────────────────

function buildLine(
  theme: Theme,
  ctx: ExtensionContext,
  pi: ExtensionAPI,
  footerData: ReadonlyFooterDataProvider,
  width: number,
): string {
  if (width <= 0) return "";

  // Ensure VCS info is fresh (bounded by TTL)
  refreshVcs(ctx.cwd, footerData);

  // Collect usage data
  const usage = collectUsage(ctx);
  const totalTokens = usage.input + usage.output;
  const contextUsage = ctx.getContextUsage();
  const modelId = ctx.model?.id;
  const modelProvider = ctx.model?.provider;
  const thinkingLevel = pi.getThinkingLevel() as string | undefined;

  // ── Left segments ──
  const left: string[] = [];

  const modelSeg = renderModel(theme, modelId, modelProvider);
  if (modelSeg) left.push(modelSeg);

  const thinkSeg = renderThinking(theme, thinkingLevel);
  if (thinkSeg) left.push(thinkSeg);

  const vcsSeg = renderVcs(theme, cachedVcsInfo);
  if (vcsSeg) left.push(vcsSeg);

  // ── Right segments ──
  const right: string[] = [];

  const tokensSeg = renderTokens(theme, totalTokens);
  if (tokensSeg) right.push(tokensSeg);

  const costSeg = renderCost(theme, usage.cost);
  if (costSeg) right.push(costSeg);

  const pLabel = providerLabel(modelProvider);
  const provCtxSeg = renderProviderContext(
    theme,
    pLabel,
    contextUsage?.tokens ?? null,
    contextUsage?.contextWindow ?? 0,
  );
  if (provCtxSeg) right.push(provCtxSeg);

  // ── Assemble ──
  const sep = ` ${theme.fg("border", "|")} `;

  const leftFiltered = left.filter(Boolean);
  const rightFiltered = right.filter(Boolean);

  if (rightFiltered.length === 0) {
    return truncateToWidth(leftFiltered.join(sep), width);
  }

  const leftText = leftFiltered.join(sep);
  const rightText = rightFiltered.join(sep);
  const usedWidth = visibleWidth(leftText) + visibleWidth(sep) + visibleWidth(rightText);
  const paddingWidth = width - usedWidth;

  if (paddingWidth <= 0) {
    // Not enough room for extra padding – truncate combined.
    return truncateToWidth(leftText + sep + rightText, width);
  }

  const padding = " ".repeat(paddingWidth);
  return truncateToWidth(leftText + padding + sep + rightText, width);
}

// ── Extension factory ───────────────────────────────────────

export default function footerExtension(pi: ExtensionAPI): void {
  let activationCount = 0;
  let enabled = false;

  /** Activate the footer for a session context. */
  const activateFooter = (ctx: ExtensionContext): void => {
    if (!ctx.hasUI) return;

    enabled = true;

    ctx.ui.setFooter((tui, theme, footerData) => {
      const unsubscribeBranchChange = footerData.onBranchChange(() => {
        lastVcsRefresh = 0;
        tui.requestRender();
      });

      const component = {
        invalidate() {
          lastVcsRefresh = 0;
        },
        render(width: number): string[] {
          return [buildLine(theme, ctx, pi, footerData, width)];
        },
        dispose() {
          unsubscribeBranchChange();
        },
      };
      return component;
    });

    // Notify on first activation
    if (activationCount === 0) {
      ctx.ui.notify("footer active", "info");
    }
    activationCount++;
  };

  // ── Event handlers ──

  pi.on("session_start", (_event, ctx) => {
    activateFooter(ctx);
  });

  pi.on("model_select", (_event, _ctx) => {
    lastVcsRefresh = 0;
  });

  pi.on("thinking_level_select", (_event, _ctx) => {
    lastVcsRefresh = 0;
  });

  pi.on("tool_execution_end", (event, _ctx) => {
    if (["bash", "edit", "write"].includes(event.toolName)) {
      lastVcsRefresh = 0;
    }
  });

  pi.on("turn_end", (_event, _ctx) => {
    lastVcsRefresh = 0;
  });

  // ── Commands ──

  pi.registerCommand("footer", {
    description: "Toggle custom footer or show status. Usage: /footer [on|off|status]",
    handler: async (args: string, ctx) => {
      const sub = args.trim().toLowerCase() || "status";

      if (sub === "status") {
        ctx.ui.notify(enabled ? "Custom footer active" : "Custom footer disabled", "info");
      } else if (sub === "off") {
        enabled = false;
        ctx.ui.setFooter(undefined);
        ctx.ui.notify("Footer: default restored", "info");
      } else if (sub === "on") {
        activateFooter(ctx);
        ctx.ui.notify("Footer: custom activated", "info");
      } else {
        ctx.ui.notify(`Footer: unknown subcommand "${sub}". Use on|off|status.`, "warning");
      }
    },
  });
}
