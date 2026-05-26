/**
 * JJ context tool for Pi.
 *
 * Provides compact, structured, read-only Jujutsu repository context so the
 * agent does not need to spend tokens on several verbose `jj` shell commands.
 */

import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";
import { Type } from "typebox";

const JJ_TIMEOUT_MS = 5_000;
const MAX_LIMIT = 50;

type JjMode = "summary" | "log" | "changes" | "recovery";

const jjContextParams = Type.Object({
  mode: Type.Optional(Type.Unsafe<JjMode>({
    type: "string",
    enum: ["summary", "log", "changes", "recovery"],
    description: "What JJ context to return. summary is the compact default.",
  })),
  revset: Type.Optional(Type.String({
    description: "Revset for log mode, or for focused inspection. Defaults to @.",
  })),
  limit: Type.Optional(Type.Integer({
    minimum: 1,
    maximum: MAX_LIMIT,
    description: "Maximum log entries, changed files, or operations to return. Default depends on mode.",
  })),
  fresh: Type.Optional(Type.Boolean({
    description: "When true/default, let JJ snapshot the working copy before reading so output is current. False uses --ignore-working-copy.",
  })),
});

interface JjContextParams {
  mode?: JjMode;
  revset?: string;
  limit?: number;
  fresh?: boolean;
}

interface CommandResult {
  ok: boolean;
  stdout: string;
  stderr: string;
  code: number;
}

interface DiffStat {
  files: number;
  insertions: number;
  deletions: number;
}

interface CurrentRevision {
  revset: string;
  changeId: string;
  commitId: string;
  description: string;
  parents: string[];
  bookmarks: string[];
}

function clampLimit(value: number | undefined, fallback: number): number {
  if (!Number.isFinite(value ?? NaN)) return fallback;
  return Math.max(1, Math.min(MAX_LIMIT, Math.trunc(value as number)));
}

function splitWords(line: string | undefined): string[] {
  return (line ?? "").trim().split(/\s+/).filter(Boolean);
}

function parseCount(raw: string): number {
  return Number.parseInt(raw.trim(), 10) || 0;
}

function parseDiffStat(raw: string): DiffStat {
  const summary = raw.trim().split("\n").at(-1) ?? "";
  const files = Number(summary.match(/(\d+) files? changed/)?.[1] ?? 0);
  const insertions = Number(summary.match(/(\d+) insertions?\(\+\)/)?.[1] ?? 0);
  const deletions = Number(summary.match(/(\d+) deletions?\(-\)/)?.[1] ?? 0);
  return { files, insertions, deletions };
}

function parseChangedFiles(raw: string, limit: number) {
  const counts: Record<string, number> = {};
  const files: Array<{ status: string; path: string }> = [];

  for (const line of raw.split("\n")) {
    const trimmed = line.trim();
    if (!trimmed) continue;
    const match = trimmed.match(/^(\S+)\s+(.*)$/);
    if (!match) continue;
    const [, status, path] = match;
    counts[status] = (counts[status] ?? 0) + 1;
    if (files.length < limit) files.push({ status, path });
  }

  return {
    total: Object.values(counts).reduce((sum, count) => sum + count, 0),
    counts,
    files,
    truncated: Object.values(counts).reduce((sum, count) => sum + count, 0) > files.length,
  };
}

function parseCurrent(raw: string, revset: string): CurrentRevision {
  const [changeId = "", commitId = "", description = "", parents = "", bookmarks = ""] = raw.split("\n");
  return {
    revset,
    changeId: changeId.trim(),
    commitId: commitId.trim(),
    description: description.trim() || "(no description set)",
    parents: splitWords(parents),
    bookmarks: splitWords(bookmarks),
  };
}

function compactError(command: string[], result: CommandResult): string {
  const stderr = result.stderr.trim();
  const stdout = result.stdout.trim();
  const message = stderr || stdout || `jj exited with code ${result.code}`;
  return `${command.join(" ")}: ${message}`;
}

async function runJj(
  pi: ExtensionAPI,
  ctx: ExtensionContext,
  args: string[],
  signal: AbortSignal | undefined,
  fresh: boolean,
): Promise<CommandResult> {
  const actualArgs = fresh ? args : ["--ignore-working-copy", ...args];
  const result = await pi.exec("jj", actualArgs, {
    cwd: ctx.cwd,
    signal,
    timeout: JJ_TIMEOUT_MS,
  });
  return {
    ok: result.code === 0,
    stdout: result.stdout,
    stderr: result.stderr,
    code: result.code,
  };
}

async function requireJjRepo(
  pi: ExtensionAPI,
  ctx: ExtensionContext,
  signal: AbortSignal | undefined,
  fresh: boolean,
) {
  const root = await runJj(pi, ctx, ["root"], signal, fresh);
  if (!root.ok) throw new Error(compactError(["jj", "root"], root));
  return root.stdout.trim();
}

async function currentRevision(
  pi: ExtensionAPI,
  ctx: ExtensionContext,
  signal: AbortSignal | undefined,
  fresh: boolean,
  revset = "@",
): Promise<CurrentRevision> {
  const template = [
    'change_id.shortest(8)',
    'commit_id.short(12)',
    'coalesce(description.first_line(), "(no description set)")',
    'parents.map(|c| c.change_id().shortest(8)).join(" ")',
    'bookmarks.join(" ")',
  ].join(' ++ "\\n" ++ ');

  const result = await runJj(pi, ctx, ["log", "-r", revset, "-n1", "-G", "-T", `${template} ++ "\\n"`], signal, fresh);
  if (!result.ok) throw new Error(compactError(["jj", "log", "-r", revset], result));
  return parseCurrent(result.stdout, revset);
}

async function nearestBookmarks(
  pi: ExtensionAPI,
  ctx: ExtensionContext,
  signal: AbortSignal | undefined,
  fresh: boolean,
): Promise<Array<{ bookmark: string; changeId: string }>> {
  const result = await runJj(pi, ctx, [
    "log",
    "-r",
    "heads(::@ & bookmarks())",
    "-G",
    "-T",
    'bookmarks.join(" ") ++ "\t" ++ change_id.shortest(8) ++ "\n"',
  ], signal, fresh);
  if (!result.ok) return [];

  return result.stdout.split("\n").flatMap((line) => {
    const trimmed = line.trim();
    if (!trimmed) return [];
    const [bookmarks = "", changeId = ""] = trimmed.split("\t");
    return splitWords(bookmarks).map((bookmark) => ({ bookmark, changeId }));
  });
}

async function operationSummary(
  pi: ExtensionAPI,
  ctx: ExtensionContext,
  signal: AbortSignal | undefined,
  fresh: boolean,
  limit: number,
) {
  const current = await runJj(pi, ctx, ["op", "log", "-n1", "-G", "-T", "self.id().short(12)"], signal, fresh);
  const recent = await runJj(pi, ctx, [
    "op",
    "log",
    "-n",
    String(limit),
    "-G",
    "-T",
    'self.id().short(12) ++ " " ++ self.description().first_line() ++ "\n"',
  ], signal, fresh);

  const id = current.ok ? current.stdout.trim() : "";
  return {
    id,
    restore: id ? `jj op restore ${id}` : undefined,
    recent: recent.ok ? recent.stdout.trim().split("\n").filter(Boolean) : [],
  };
}

async function changesSummary(
  pi: ExtensionAPI,
  ctx: ExtensionContext,
  signal: AbortSignal | undefined,
  fresh: boolean,
  limit: number,
  revset = "@",
) {
  const targetRevset = `(${revset})`;
  const summary = await runJj(pi, ctx, ["diff", "-r", revset, "--summary"], signal, fresh);
  const stat = await runJj(pi, ctx, ["diff", "-r", revset, "--stat"], signal, fresh);
  const conflictsAtTarget = await runJj(pi, ctx, ["log", "-r", `conflicts() & ${targetRevset}`, "--count"], signal, fresh);
  const conflictsAll = await runJj(pi, ctx, ["log", "-r", "conflicts()", "--count"], signal, fresh);

  if (!summary.ok) throw new Error(compactError(["jj", "diff", "-r", revset, "--summary"], summary));

  const changed = parseChangedFiles(summary.stdout, limit);
  return {
    clean: changed.total === 0,
    changed,
    stat: stat.ok ? parseDiffStat(stat.stdout) : { files: changed.total, insertions: 0, deletions: 0 },
    conflicts: {
      atCurrent: conflictsAtTarget.ok ? parseCount(conflictsAtTarget.stdout) : 0,
      visible: conflictsAll.ok ? parseCount(conflictsAll.stdout) : 0,
    },
  };
}

async function recentLog(
  pi: ExtensionAPI,
  ctx: ExtensionContext,
  signal: AbortSignal | undefined,
  fresh: boolean,
  revset: string,
  limit: number,
): Promise<string[]> {
  const result = await runJj(pi, ctx, [
    "log",
    "-r",
    revset,
    "-n",
    String(limit),
    "-G",
    "-T",
    'change_id.shortest(8) ++ " " ++ if(empty, "(empty) ", "") ++ coalesce(description.first_line(), "(no description set)") ++ "\n"',
  ], signal, fresh);
  if (!result.ok) throw new Error(compactError(["jj", "log", "-r", revset], result));
  return result.stdout.trim().split("\n").filter(Boolean);
}

function toolText(mode: JjMode, data: unknown): string {
  return `jj_context ${mode}:\n${JSON.stringify(data, null, 2)}`;
}

export default function jjContextExtension(pi: ExtensionAPI) {
  pi.registerTool({
    name: "jj_context",
    label: "JJ Context",
    description: "Return compact, structured, read-only Jujutsu repository context. Use instead of multiple verbose jj status/log/diff/op bash commands when inspecting repository state.",
    promptSnippet: "Inspect compact JJ repository context (status, current change, short log, operation restore info).",
    promptGuidelines: [
      "Use jj_context before JJ/Git history inspection when compact repository context is enough; use bash only for specific JJ commands or full diffs.",
      "Do not use jj_context for mutating JJ operations; it is read-only and intended for status/log/recovery context.",
    ],
    parameters: jjContextParams,

    async execute(_toolCallId, params: JjContextParams, signal, _onUpdate, ctx) {
      const mode = (params.mode ?? "summary") as JjMode;
      const fresh = params.fresh ?? true;
      const limit = clampLimit(params.limit, mode === "summary" ? 5 : mode === "changes" ? 30 : 10);
      const revset = params.revset?.trim() || (mode === "log" ? "@::" : "@");

      const root = await requireJjRepo(pi, ctx, signal, fresh);
      const versionResult = await runJj(pi, ctx, ["--version"], signal, fresh);
      const version = versionResult.ok ? versionResult.stdout.trim() : "unknown";

      if (mode === "log") {
        const data = {
          vcs: "jj",
          version,
          root,
          revset,
          limit,
          log: await recentLog(pi, ctx, signal, fresh, revset, limit),
        };
        return { content: [{ type: "text", text: toolText(mode, data) }], details: data };
      }

      if (mode === "changes") {
        const data = {
          vcs: "jj",
          version,
          root,
          current: await currentRevision(pi, ctx, signal, fresh, revset),
          changes: await changesSummary(pi, ctx, signal, fresh, limit, revset),
        };
        return { content: [{ type: "text", text: toolText(mode, data) }], details: data };
      }

      if (mode === "recovery") {
        const data = {
          vcs: "jj",
          version,
          root,
          operation: await operationSummary(pi, ctx, signal, fresh, limit),
        };
        return { content: [{ type: "text", text: toolText(mode, data) }], details: data };
      }

      // Run sequentially when fresh=true so JJ doesn't create concurrent operations
      // while snapshotting the working copy.
      const current = await currentRevision(pi, ctx, signal, fresh);
      const bookmarks = await nearestBookmarks(pi, ctx, signal, fresh);
      const changes = await changesSummary(pi, ctx, signal, fresh, limit);
      const operation = await operationSummary(pi, ctx, signal, fresh, Math.min(limit, 5));
      const log = await recentLog(pi, ctx, signal, fresh, revset, limit);

      const data = {
        vcs: "jj",
        version,
        root,
        current,
        nearestBookmarks: bookmarks,
        changes,
        operation,
        log,
      };
      return { content: [{ type: "text", text: toolText(mode, data) }], details: data };
    },
  });
}
