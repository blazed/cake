/**
 * JJ TODO tool for Pi.
 *
 * Provides compact, structured helpers for the mechanical parts of the JJ TODO
 * workflow while leaving planning and task judgment to the jj-todo skill.
 */

import { randomUUID } from "node:crypto";
import { StringEnum } from "@earendil-works/pi-ai";
import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";
import { Text } from "@earendil-works/pi-tui";
import { Type } from "typebox";

const JJ_TIMEOUT_MS = 8_000;
const MAX_LIMIT = 50;
const PREVIEW_TTL_MS = 10 * 60_000;
const MAX_PREVIEWS = 64;

const TASK_FLAGS = ["draft", "todo", "wip", "blocked", "standby", "untested", "review", "done"] as const;
const CREATE_FLAGS = new Set<TaskFlag>(["draft", "todo"]);
const ACTIONS = ["list", "next", "create", "update", "check"] as const;

type TaskFlag = (typeof TASK_FLAGS)[number];
type JjTodoAction = (typeof ACTIONS)[number];

interface JjTodoParams {
  action: JjTodoAction;
  flag?: TaskFlag;
  rev?: string;
  parent?: string;
  title?: string;
  body?: string;
  draft?: boolean;
  limit?: number;
  fresh?: boolean;
  dryRun?: boolean;
  previewToken?: string;
}

interface CommandResult {
  ok: boolean;
  stdout: string;
  stderr: string;
  code: number;
}

interface WouldRun {
  command: "jj";
  args: string[];
}

interface TaskInfo {
  changeId: string;
  commitId: string;
  flag: TaskFlag;
  title: string;
  firstLine: string;
  parents: string[];
}

interface RevisionIdentity {
  changeId: string;
  commitId: string;
}

interface PreviewRecord {
  action: "create" | "update";
  root: string;
  operationId: string;
  requestKey: string;
  target: RevisionIdentity;
  args: string[];
  flag: TaskFlag;
  from?: TaskFlag;
  currentDescription?: string;
  nextDescription?: string;
  message?: string;
  changed?: boolean;
  expiresAt: number;
}

const previews = new Map<string, PreviewRecord>();
let toolQueue: Promise<void> = Promise.resolve();

const jjTodoParams = Type.Object({
  action: StringEnum(ACTIONS, {
    description: "Operation to perform: list tasks, find next child tasks, create a task, update a task flag, or check task state.",
  }),
  flag: Type.Optional(StringEnum(TASK_FLAGS, {
    description: "Task flag for list/update. Create accepts only draft or todo.",
  })),
  rev: Type.Optional(Type.String({
    description: "Revision/change to inspect or update. Defaults to @ for next/update and must resolve to exactly one revision.",
  })),
  parent: Type.Optional(Type.String({
    description: "Parent revision for create. Defaults to @ and must resolve to exactly one revision.",
  })),
  title: Type.Optional(Type.String({
    description: "Task title for create. The tool prefixes it with [task:<flag>].",
  })),
  body: Type.Optional(Type.String({
    description: "Optional task body/specification for create.",
  })),
  draft: Type.Optional(Type.Boolean({
    description: "Create with [task:draft] when action=create and flag is omitted.",
  })),
  limit: Type.Optional(Type.Integer({
    minimum: 1,
    maximum: MAX_LIMIT,
    description: "Maximum tasks to return. Default 20, max 50.",
  })),
  fresh: Type.Optional(Type.Boolean({
    description: "For read-only actions and previews, true/default lets JJ snapshot first; false uses --ignore-working-copy.",
  })),
  dryRun: Type.Optional(Type.Boolean({
    description: "Create/update default to preview-only. Set false with the matching previewToken to apply.",
  })),
  previewToken: Type.Optional(Type.String({
    description: "One-use token returned by a create/update preview. Required with dryRun=false.",
  })),
});

function clampLimit(value: number | undefined, fallback = 20): number {
  if (!Number.isFinite(value ?? NaN)) return fallback;
  return Math.max(1, Math.min(MAX_LIMIT, Math.trunc(value as number)));
}

function splitWords(line: string | undefined): string[] {
  return (line ?? "").trim().split(/\s+/).filter(Boolean);
}

function isTaskFlag(value: string | undefined): value is TaskFlag {
  return TASK_FLAGS.includes(value as TaskFlag);
}

function detectTask(firstLine: string): { flag?: TaskFlag; rawFlag?: string; title: string } {
  const match = firstLine.match(/^\[task:([^\]]+)\]\s*(.*)$/);
  const rawFlag = match?.[1];
  return {
    flag: isTaskFlag(rawFlag) ? rawFlag : undefined,
    rawFlag,
    title: match?.[2]?.trim() ?? firstLine.trim(),
  };
}

function parseTaskLine(line: string): TaskInfo | undefined {
  const [changeId = "", commitId = "", firstLine = "", parents = ""] = line.split("\t");
  const task = detectTask(firstLine);
  if (!changeId || !task.flag) return undefined;
  return {
    changeId,
    commitId,
    flag: task.flag,
    title: task.title,
    firstLine,
    parents: splitWords(parents),
  };
}

function compactError(command: string[], result: CommandResult): string {
  const stderr = result.stderr.trim();
  const stdout = result.stdout.trim();
  const message = stderr || stdout || `jj exited with code ${result.code}`;
  return `${command.join(" ")}: ${message}`;
}

function wouldRun(args: string[]): WouldRun {
  return { command: "jj", args };
}

function exactRevision(commitId: string): string {
  return `commit_id(${commitId})`;
}

function createRequestKey(parent: string, flag: TaskFlag, title: string, body: string): string {
  return JSON.stringify({ action: "create", parent, flag, title, body });
}

function updateRequestKey(rev: string, flag: TaskFlag): string {
  return JSON.stringify({ action: "update", rev, flag });
}

function prunePreviews(): void {
  const now = Date.now();
  for (const [token, preview] of previews) {
    if (preview.expiresAt <= now) previews.delete(token);
  }
  while (previews.size >= MAX_PREVIEWS) {
    const oldest = previews.keys().next().value as string | undefined;
    if (!oldest) break;
    previews.delete(oldest);
  }
}

function savePreview(preview: Omit<PreviewRecord, "expiresAt">): string {
  prunePreviews();
  const token = randomUUID();
  previews.set(token, { ...preview, expiresAt: Date.now() + PREVIEW_TTL_MS });
  return token;
}

function consumePreview(token: string | undefined, action: PreviewRecord["action"], requestKey: string): PreviewRecord {
  if (!token) throw new Error(`action=${action} with dryRun=false requires previewToken from a matching preview`);
  const preview = previews.get(token);
  previews.delete(token);
  if (!preview || preview.expiresAt <= Date.now()) throw new Error("previewToken is invalid or expired; preview the mutation again");
  if (preview.action !== action || preview.requestKey !== requestKey) {
    throw new Error("previewToken does not match this mutation request; preview the exact request again");
  }
  return preview;
}

async function withToolLock<T>(operation: () => Promise<T>): Promise<T> {
  const previous = toolQueue;
  let release!: () => void;
  toolQueue = new Promise<void>((resolve) => {
    release = resolve;
  });
  await previous;
  try {
    return await operation();
  } finally {
    release();
  }
}

async function runJj(
  pi: ExtensionAPI,
  ctx: ExtensionContext,
  args: string[],
  signal: AbortSignal | undefined,
  fresh = true,
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
 ): Promise<string> {
  const root = await runJj(pi, ctx, ["root"], signal, fresh);
  if (!root.ok) throw new Error(compactError(["jj", "root"], root));
  return root.stdout.trim();
}

async function currentOperationId(
  pi: ExtensionAPI,
  ctx: ExtensionContext,
  signal: AbortSignal | undefined,
 ): Promise<string> {
  const result = await runJj(pi, ctx, ["op", "log", "-n1", "-G", "-T", "self.id()"], signal, false);
  if (!result.ok) throw new Error(compactError(["jj", "op", "log", "-n1"], result));
  const id = result.stdout.trim();
  if (!id) throw new Error("JJ returned no current operation ID");
  return id;
}

async function resolveOneRevision(
  pi: ExtensionAPI,
  ctx: ExtensionContext,
  signal: AbortSignal | undefined,
  revset: string,
  fresh: boolean,
 ): Promise<RevisionIdentity> {
  const template = 'change_id ++ "\t" ++ commit_id ++ "\n"';
  const result = await runJj(pi, ctx, ["log", "-r", revset, "-G", "-T", template], signal, fresh);
  if (!result.ok) throw new Error(compactError(["jj", "log", "-r", revset], result));
  const matches = result.stdout.trim().split("\n").filter(Boolean).map((line) => {
    const [changeId = "", commitId = ""] = line.split("\t");
    return { changeId, commitId };
  }).filter((identity) => identity.changeId && identity.commitId);
  if (matches.length !== 1) {
    throw new Error(`revision expression ${JSON.stringify(revset)} resolved to ${matches.length} revisions; expected exactly one`);
  }
  return matches[0];
}

async function revisionChildren(
  pi: ExtensionAPI,
  ctx: ExtensionContext,
  signal: AbortSignal | undefined,
  parent: RevisionIdentity,
 ): Promise<RevisionIdentity[]> {
  const revset = `children(${exactRevision(parent.commitId)})`;
  const template = 'change_id ++ "\t" ++ commit_id ++ "\n"';
  const result = await runJj(pi, ctx, ["log", "-r", revset, "-G", "-T", template], signal, false);
  if (!result.ok) throw new Error(compactError(["jj", "log", "-r", revset], result));
  return result.stdout.trim().split("\n").filter(Boolean).map((line) => {
    const [changeId = "", commitId = ""] = line.split("\t");
    return { changeId, commitId };
  }).filter((identity) => identity.changeId && identity.commitId);
}

async function taskLog(
  pi: ExtensionAPI,
  ctx: ExtensionContext,
  signal: AbortSignal | undefined,
  revset: string,
  limit: number | undefined,
  fresh: boolean,
 ): Promise<TaskInfo[]> {
  const template = [
    "change_id.shortest(8)",
    "commit_id.short(12)",
    'coalesce(description.first_line(), "")',
    'parents.map(|c| c.change_id().shortest(8)).join(" ")',
  ].join(' ++ "\t" ++ ');
  const args = ["log", "-r", revset, "-G", "-T", `${template} ++ "\n"`];
  if (limit !== undefined) args.splice(3, 0, "-n", String(limit));
  const result = await runJj(pi, ctx, args, signal, fresh);
  if (!result.ok) throw new Error(compactError(["jj", "log", "-r", revset], result));
  return result.stdout.trim().split("\n").flatMap((line) => {
    const task = parseTaskLine(line);
    return task ? [task] : [];
  });
}

async function invalidTaskEntries(
  pi: ExtensionAPI,
  ctx: ExtensionContext,
  signal: AbortSignal | undefined,
  revset = 'description(substring:"[task:")',
): Promise<Array<{ changeId: string; firstLine: string; flag: string }>> {
  const template = 'change_id.shortest(8) ++ "\t" ++ coalesce(description.first_line(), "") ++ "\n"';
  const result = await runJj(pi, ctx, ["log", "-r", revset, "-G", "-T", template], signal, false);
  if (!result.ok) throw new Error(compactError(["jj", "log", "-r", revset], result));
  return result.stdout.trim().split("\n").filter(Boolean).flatMap((line) => {
    const [changeId = "", firstLine = ""] = line.split("\t");
    const task = detectTask(firstLine);
    return task.rawFlag && !task.flag ? [{ changeId, firstLine, flag: task.rawFlag }] : [];
  });
}

async function taskDescription(
  pi: ExtensionAPI,
  ctx: ExtensionContext,
  signal: AbortSignal | undefined,
  revision: RevisionIdentity,
  fresh: boolean,
 ): Promise<string> {
  const revset = exactRevision(revision.commitId);
  const result = await runJj(pi, ctx, ["log", "-r", revset, "-G", "-T", "description"], signal, fresh);
  if (!result.ok) throw new Error(compactError(["jj", "log", "-r", revset], result));
  return result.stdout;
}

async function taskInfo(
  pi: ExtensionAPI,
  ctx: ExtensionContext,
  signal: AbortSignal | undefined,
  revision: RevisionIdentity,
  fresh: boolean,
 ): Promise<TaskInfo | undefined> {
  const tasks = await taskLog(pi, ctx, signal, exactRevision(revision.commitId), 1, fresh);
  return tasks[0];
}

function revsetForFlag(flag?: TaskFlag): string {
  if (flag) return `description(substring:"[task:${flag}]")`;
  return TASK_FLAGS.map((taskFlag) => `description(substring:"[task:${taskFlag}]")`).join(" | ");
}

async function listTasks(pi: ExtensionAPI, ctx: ExtensionContext, signal: AbortSignal | undefined, params: JjTodoParams) {
  const limit = clampLimit(params.limit);
  const fresh = params.fresh ?? true;
  await requireJjRepo(pi, ctx, signal, fresh);
  const allTasks = await taskLog(pi, ctx, signal, revsetForFlag(params.flag), undefined, false);
  const tasks = allTasks.slice(0, limit);
  const invalidTasks = params.flag ? [] : await invalidTaskEntries(pi, ctx, signal);
  return { action: "list", flag: params.flag, limit, tasks, invalidTasks, truncated: allTasks.length > tasks.length };
}

async function nextTasks(pi: ExtensionAPI, ctx: ExtensionContext, signal: AbortSignal | undefined, params: JjTodoParams) {
  const rev = params.rev?.trim() || "@";
  const limit = clampLimit(params.limit);
  const fresh = params.fresh ?? true;
  await requireJjRepo(pi, ctx, signal, fresh);
  const selected = await resolveOneRevision(pi, ctx, signal, rev, fresh);
  const current = await taskInfo(pi, ctx, signal, selected, false);
  const childRevset = `children(${exactRevision(selected.commitId)})`;
  const allChildren = await taskLog(pi, ctx, signal, childRevset, undefined, false);
  const children = allChildren.slice(0, limit);
  const invalidChildren = await invalidTaskEntries(pi, ctx, signal, childRevset);
  const ready: TaskInfo[] = [];
  const drafts: TaskInfo[] = [];
  const blocked: Array<TaskInfo & { blockedBy: TaskInfo[] }> = [];
  const notReady: TaskInfo[] = [];
  const done: TaskInfo[] = [];

  for (const child of children) {
    if (child.flag === "draft") {
      drafts.push(child);
      continue;
    }
    if (child.flag === "done") {
      done.push(child);
      continue;
    }
    if (child.flag !== "todo") {
      notReady.push(child);
      continue;
    }

    const childRev = `change_id(${child.changeId})`;
    const ancestors = await taskLog(pi, ctx, signal, `ancestors(${childRev}) ~ ${childRev}`, undefined, false);
    const blockers = ancestors.filter((task) => task.flag !== "done");
    if (blockers.length === 0) ready.push(child);
    else blocked.push({ ...child, blockedBy: blockers });
  }

  return {
    action: "next",
    rev,
    current,
    ready,
    drafts,
    blocked,
    notReady,
    done,
    invalidChildren,
    truncated: allChildren.length > children.length,
  };
}

async function createTask(pi: ExtensionAPI, ctx: ExtensionContext, signal: AbortSignal | undefined, params: JjTodoParams) {
  const dryRun = params.dryRun ?? true;
  const parent = params.parent?.trim() || "@";
  const title = params.title?.trim();
  if (!title) throw new Error("action=create requires title");

  const flag = params.flag ?? (params.draft ? "draft" : "todo");
  if (!isTaskFlag(flag) || !CREATE_FLAGS.has(flag)) throw new Error("action=create permits only draft or todo");

  const body = params.body?.trim() ?? "";
  const message = body ? `[task:${flag}] ${title}\n\n${body}` : `[task:${flag}] ${title}`;
  const requestKey = createRequestKey(parent, flag, title, body);

  if (dryRun) {
    const fresh = params.fresh ?? true;
    const root = await requireJjRepo(pi, ctx, signal, fresh);
    const resolvedParent = await resolveOneRevision(pi, ctx, signal, parent, false);
    const args = ["new", "--no-edit", exactRevision(resolvedParent.commitId), "-m", message];
    const operationId = await currentOperationId(pi, ctx, signal);
    const previewToken = savePreview({
      action: "create",
      root,
      operationId,
      requestKey,
      target: resolvedParent,
      args,
      flag,
      message,
    });
    return {
      action: "create",
      dryRun: true,
      parent,
      resolvedParent,
      flag,
      title,
      message,
      previewToken,
      wouldRun: wouldRun(args),
      previewTask: { flag, title, firstLine: `[task:${flag}] ${title}`, parent, body },
    };
  }

  const preview = consumePreview(params.previewToken, "create", requestKey);
  const root = await requireJjRepo(pi, ctx, signal, false);
  if (root !== preview.root) throw new Error("previewToken belongs to a different JJ repository");
  const operationId = await currentOperationId(pi, ctx, signal);
  if (operationId !== preview.operationId) throw new Error("JJ repository changed after preview; preview the mutation again");

  const before = new Set((await revisionChildren(pi, ctx, signal, preview.target)).map((identity) => identity.changeId));
  const result = await runJj(pi, ctx, preview.args, signal, false);
  if (!result.ok) throw new Error(compactError(["jj", ...preview.args], result));
  const created = (await revisionChildren(pi, ctx, signal, preview.target)).filter((identity) => !before.has(identity.changeId));
  if (created.length !== 1) {
    throw new Error(`JJ mutation completed but child-set query found ${created.length} new revisions; inspect the repository before continuing`);
  }
  const task = await taskInfo(pi, ctx, signal, created[0], false);
  return { action: "create", parent, resolvedParent: preview.target, created: created[0].changeId, revision: created[0], task };
}

async function updateTask(pi: ExtensionAPI, ctx: ExtensionContext, signal: AbortSignal | undefined, params: JjTodoParams) {
  const dryRun = params.dryRun ?? true;
  const rev = params.rev?.trim() || "@";
  const flag = params.flag;
  if (!flag) throw new Error("action=update requires flag");
  if (!isTaskFlag(flag)) throw new Error(`invalid task flag: ${flag}`);
  const requestKey = updateRequestKey(rev, flag);

  if (dryRun) {
    const fresh = params.fresh ?? true;
    const root = await requireJjRepo(pi, ctx, signal, fresh);
    const resolvedRevision = await resolveOneRevision(pi, ctx, signal, rev, false);
    const currentDescription = await taskDescription(pi, ctx, signal, resolvedRevision, false);
    const firstLine = currentDescription.split(/\r?\n/, 1)[0] ?? "";
    const current = detectTask(firstLine);
    if (current.rawFlag && !current.flag) {
      throw new Error(`revision has unsupported task flag ${JSON.stringify(current.rawFlag)}; repair it explicitly before update`);
    }
    const nextDescription = current.flag
      ? currentDescription.replace(/^\[task:[^\]]+\]/, `[task:${flag}]`)
      : `[task:${flag}] ${currentDescription}`;
    const changed = current.flag !== flag;
    const args = ["describe", exactRevision(resolvedRevision.commitId), "-m", nextDescription];
    const operationId = await currentOperationId(pi, ctx, signal);
    const previewToken = savePreview({
      action: "update",
      root,
      operationId,
      requestKey,
      target: resolvedRevision,
      args,
      flag,
      from: current.flag,
      currentDescription,
      nextDescription,
      changed,
    });
    const nextFirstLine = nextDescription.split(/\r?\n/, 1)[0] ?? "";
    const previewTask = detectTask(nextFirstLine);
    return {
      action: "update",
      dryRun: true,
      rev,
      resolvedRevision,
      changed,
      from: current.flag,
      to: flag,
      currentDescription,
      nextDescription,
      previewToken,
      wouldRun: wouldRun(args),
      previewTask: { flag: previewTask.flag, title: previewTask.title, firstLine: nextFirstLine, rev },
    };
  }

  const preview = consumePreview(params.previewToken, "update", requestKey);
  const root = await requireJjRepo(pi, ctx, signal, false);
  if (root !== preview.root) throw new Error("previewToken belongs to a different JJ repository");
  const operationId = await currentOperationId(pi, ctx, signal);
  if (operationId !== preview.operationId) throw new Error("JJ repository changed after preview; preview the mutation again");

  if (preview.changed) {
    const result = await runJj(pi, ctx, preview.args, signal, false);
    if (!result.ok) throw new Error(compactError(["jj", ...preview.args], result));
  }
  const resolvedRevision = await resolveOneRevision(
    pi,
    ctx,
    signal,
    `change_id(${preview.target.changeId})`,
    false,
  );
  const task = await taskInfo(pi, ctx, signal, resolvedRevision, false);
  return {
    action: "update",
    rev,
    resolvedRevision,
    changed: preview.changed ?? false,
    from: preview.from,
    to: flag,
    task,
  };
}

async function checkTasks(pi: ExtensionAPI, ctx: ExtensionContext, signal: AbortSignal | undefined, params: JjTodoParams) {
  const limit = clampLimit(params.limit);
  const fresh = params.fresh ?? true;
  await requireJjRepo(pi, ctx, signal, fresh);
  const allTasks = await taskLog(pi, ctx, signal, revsetForFlag(), undefined, false);
  const invalidTasks = await invalidTaskEntries(pi, ctx, signal);
  const conflicts = await runJj(pi, ctx, ["log", "-r", "conflicts()", "--count"], signal, false);
  if (!conflicts.ok) {
    throw new Error(compactError(["jj", "log", "-r", "conflicts()", "--count"], conflicts));
  }
  const conflictCount = Number.parseInt(conflicts.stdout.trim(), 10) || 0;
  const counts = Object.fromEntries(TASK_FLAGS.map((flag) => [flag, allTasks.filter((task) => task.flag === flag).length]));
  const wip = allTasks.filter((task) => task.flag === "wip");
  const issues: string[] = [];
  if (conflictCount > 0) issues.push(`${conflictCount} visible conflict revision(s)`);
  if (wip.length > 1) issues.push(`multiple [task:wip] revisions: ${wip.map((task) => task.changeId).join(", ")}`);
  if (invalidTasks.length > 0) {
    issues.push(`unsupported task flag(s): ${invalidTasks.map((task) => `${task.changeId}=${task.flag}`).join(", ")}`);
  }
  return { action: "check", ok: issues.length === 0, issues, counts, wip, invalidTasks, conflictCount, limit };
}

function toolText(action: JjTodoAction, data: unknown): string {
  return `jj_todo ${action}:\n${JSON.stringify(data, null, 2)}`;
}

export default function jjTodoExtension(pi: ExtensionAPI) {
  pi.registerTool({
    name: "jj_todo",
    label: "JJ TODO",
    description: "Perform mechanical JJ TODO workflow operations. Planning stays with the agent. Create/update preview by default; applying requires dryRun:false and the previewToken from that exact preview. Use direct JJ commands for graph edits or unusual mutations.",
    parameters: jjTodoParams,
    renderShell: "self",
    renderCall(args, theme) {
      const target = args.rev ?? args.parent;
      const detail = [args.action, args.flag, target].filter(Boolean).join(" ");
      return new Text(
        theme.fg("toolTitle", theme.bold("JJ TODO")) + ` ${theme.fg("accent", detail)}`,
        0,
        0,
      );
    },
    renderResult(result, options, theme, context) {
      const details = result.details as {
        action?: JjTodoAction;
        ok?: boolean;
        issues?: unknown[];
        tasks?: unknown[];
        ready?: unknown[];
        task?: { firstLine?: string };
        previewTask?: { firstLine?: string };
      } | undefined;
      const action = details?.action ?? context.args.action;
      const subject = details?.task?.firstLine ?? details?.previewTask?.firstLine;
      const fallback = subject
        ?? (action === "check"
          ? details?.ok ? "workflow healthy" : `${details?.issues?.length ?? 0} workflow issue(s)`
          : action === "next"
            ? `${details?.ready?.length ?? 0} task(s) ready`
            : `${details?.tasks?.length ?? 0} task(s)`);
      const raw = result.content.find((item) => item.type === "text")?.text;
      const summary = context.isError ? raw?.split(/\r?\n/, 1)[0] ?? fallback : fallback;
      const color = context.isError ? "error" : "success";
      let text = theme.fg(color, `${context.isError ? "x" : "✓"} ${summary}`);
      if (options.expanded && raw && raw !== summary) text += `\n${raw}`;
      return new Text(text, 0, 0);
    },

    async execute(_toolCallId, params: JjTodoParams, signal, _onUpdate, ctx) {
      const action = params.action;
      const data = await withToolLock(async () => {
        if (action === "list") return listTasks(pi, ctx, signal, params);
        if (action === "next") return nextTasks(pi, ctx, signal, params);
        if (action === "create") return createTask(pi, ctx, signal, params);
        if (action === "update") return updateTask(pi, ctx, signal, params);
        if (action === "check") return checkTasks(pi, ctx, signal, params);
        throw new Error(`unknown jj_todo action: ${action}`);
      });
      return { content: [{ type: "text", text: toolText(action, data) }], details: data };
    },
  });
}
