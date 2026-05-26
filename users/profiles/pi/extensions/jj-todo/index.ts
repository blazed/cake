/**
 * JJ TODO tool for Pi.
 *
 * Provides compact, structured helpers for the mechanical parts of the JJ TODO
 * workflow while leaving planning and task judgment to the jj-todo skill.
 */

import { StringEnum } from "@earendil-works/pi-ai";
import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";
import { Type } from "typebox";

const JJ_TIMEOUT_MS = 8_000;
const MAX_LIMIT = 50;

const TASK_FLAGS = ["draft", "todo", "wip", "blocked", "standby", "untested", "review", "done"] as const;
const BLOCKING_FLAGS = new Set<TaskFlag>(["draft", "todo", "wip", "blocked"]);
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
}

interface CommandResult {
  ok: boolean;
  stdout: string;
  stderr: string;
  code: number;
}

interface TaskInfo {
  changeId: string;
  commitId: string;
  flag: TaskFlag;
  title: string;
  firstLine: string;
  parents: string[];
}

const jjTodoParams = Type.Object({
  action: StringEnum(ACTIONS, {
    description: "Operation to perform: list tasks, find next child tasks, create a task, update a task flag, or check task state.",
  }),
  flag: Type.Optional(StringEnum(TASK_FLAGS, {
    description: "Task flag for list/create/update actions.",
  })),
  rev: Type.Optional(Type.String({
    description: "Revision/change to inspect or update. Defaults to @ for next/update.",
  })),
  parent: Type.Optional(Type.String({
    description: "Parent revision for create. Defaults to @.",
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
    description: "For read-only actions, true/default lets JJ snapshot first; false uses --ignore-working-copy.",
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

function detectTask(firstLine: string): { flag?: TaskFlag; title: string } {
  const match = firstLine.match(/^\[task:([^\]]+)\]\s*(.*)$/);
  const flag = match?.[1];
  return {
    flag: isTaskFlag(flag) ? flag : undefined,
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

async function requireJjRepo(pi: ExtensionAPI, ctx: ExtensionContext, signal: AbortSignal | undefined, fresh: boolean) {
  const root = await runJj(pi, ctx, ["root"], signal, fresh);
  if (!root.ok) throw new Error(compactError(["jj", "root"], root));
  return root.stdout.trim();
}

async function taskLog(
  pi: ExtensionAPI,
  ctx: ExtensionContext,
  signal: AbortSignal | undefined,
  revset: string,
  limit: number,
  fresh: boolean,
): Promise<TaskInfo[]> {
  const template = [
    'change_id.shortest(8)',
    'commit_id.short(12)',
    'coalesce(description.first_line(), "")',
    'parents.map(|c| c.change_id().shortest(8)).join(" ")',
  ].join(' ++ "\t" ++ ');

  const result = await runJj(pi, ctx, ["log", "-r", revset, "-n", String(limit), "-G", "-T", `${template} ++ "\n"`], signal, fresh);
  if (!result.ok) throw new Error(compactError(["jj", "log", "-r", revset], result));
  return result.stdout.trim().split("\n").flatMap((line) => {
    const task = parseTaskLine(line);
    return task ? [task] : [];
  });
}

async function taskDescription(
  pi: ExtensionAPI,
  ctx: ExtensionContext,
  signal: AbortSignal | undefined,
  rev: string,
  fresh: boolean,
): Promise<string> {
  const result = await runJj(pi, ctx, ["log", "-r", rev, "-n", "1", "-G", "-T", "description"], signal, fresh);
  if (!result.ok) throw new Error(compactError(["jj", "log", "-r", rev], result));
  return result.stdout;
}

async function taskInfo(
  pi: ExtensionAPI,
  ctx: ExtensionContext,
  signal: AbortSignal | undefined,
  rev: string,
  fresh: boolean,
): Promise<TaskInfo | undefined> {
  const tasks = await taskLog(pi, ctx, signal, rev, 1, fresh);
  return tasks[0];
}

function revsetForFlag(flag?: TaskFlag): string {
  return flag ? `description(substring:"[task:${flag}]")` : 'description(substring:"[task:")';
}

async function listTasks(pi: ExtensionAPI, ctx: ExtensionContext, signal: AbortSignal | undefined, params: JjTodoParams) {
  const limit = clampLimit(params.limit);
  const fresh = params.fresh ?? true;
  await requireJjRepo(pi, ctx, signal, fresh);
  const tasks = await taskLog(pi, ctx, signal, revsetForFlag(params.flag), limit, fresh);
  return { action: "list", flag: params.flag, limit, tasks, truncated: tasks.length >= limit };
}

async function nextTasks(pi: ExtensionAPI, ctx: ExtensionContext, signal: AbortSignal | undefined, params: JjTodoParams) {
  const rev = params.rev?.trim() || "@";
  const limit = clampLimit(params.limit);
  const fresh = params.fresh ?? true;
  await requireJjRepo(pi, ctx, signal, fresh);

  const current = await taskInfo(pi, ctx, signal, rev, fresh);
  const children = await taskLog(pi, ctx, signal, `children(${rev})`, limit, fresh);
  const ready: TaskInfo[] = [];
  const drafts: TaskInfo[] = [];
  const blocked: Array<TaskInfo & { blockedBy: TaskInfo[] }> = [];
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

    const parentTasks = await taskLog(pi, ctx, signal, `parents(${child.changeId}) ~ (${rev})`, MAX_LIMIT, fresh);
    const blockers = parentTasks.filter((task) => BLOCKING_FLAGS.has(task.flag));
    if (blockers.length === 0) {
      ready.push(child);
    } else {
      blocked.push({ ...child, blockedBy: blockers });
    }
  }

  return { action: "next", rev, current, ready, drafts, blocked, done };
}

async function createTask(pi: ExtensionAPI, ctx: ExtensionContext, signal: AbortSignal | undefined, params: JjTodoParams) {
  const parent = params.parent?.trim() || "@";
  const title = params.title?.trim();
  if (!title) throw new Error("action=create requires title");

  const flag = params.flag ?? (params.draft ? "draft" : "todo");
  if (!isTaskFlag(flag)) throw new Error(`invalid task flag: ${flag}`);

  await requireJjRepo(pi, ctx, signal, true);
  const body = params.body?.trim();
  const message = body ? `[task:${flag}] ${title}\n\n${body}` : `[task:${flag}] ${title}`;
  const result = await runJj(pi, ctx, ["new", "--no-edit", parent, "-m", message], signal, true);
  if (!result.ok) throw new Error(compactError(["jj", "new", "--no-edit", parent], result));

  const created = result.stdout.match(/Created new commit\s+([a-z]+)/)?.[1];
  const task = created ? await taskInfo(pi, ctx, signal, created, true) : undefined;
  return { action: "create", parent, created, task, stdout: result.stdout.trim() };
}

async function updateTask(pi: ExtensionAPI, ctx: ExtensionContext, signal: AbortSignal | undefined, params: JjTodoParams) {
  const rev = params.rev?.trim() || "@";
  const flag = params.flag;
  if (!flag) throw new Error("action=update requires flag");
  if (!isTaskFlag(flag)) throw new Error(`invalid task flag: ${flag}`);

  await requireJjRepo(pi, ctx, signal, true);
  const currentDescription = await taskDescription(pi, ctx, signal, rev, true);
  const firstLine = currentDescription.split(/\r?\n/, 1)[0] ?? "";
  const current = detectTask(firstLine);

  if (current.flag === flag) {
    const task = await taskInfo(pi, ctx, signal, rev, true);
    return { action: "update", rev, changed: false, from: current.flag, to: flag, task };
  }

  const nextDescription = current.flag
    ? currentDescription.replace(/^\[task:[^\]]+\]/, `[task:${flag}]`)
    : `[task:${flag}] ${currentDescription}`;

  const result = await runJj(pi, ctx, ["describe", rev, "-m", nextDescription], signal, true);
  if (!result.ok) throw new Error(compactError(["jj", "describe", rev], result));

  const task = await taskInfo(pi, ctx, signal, rev, true);
  return { action: "update", rev, changed: true, from: current.flag, to: flag, task };
}

async function checkTasks(pi: ExtensionAPI, ctx: ExtensionContext, signal: AbortSignal | undefined, params: JjTodoParams) {
  const limit = clampLimit(params.limit);
  const fresh = params.fresh ?? true;
  await requireJjRepo(pi, ctx, signal, fresh);

  const tasks = await taskLog(pi, ctx, signal, revsetForFlag(), limit, fresh);
  const conflicts = await runJj(pi, ctx, ["log", "-r", "conflicts()", "--count"], signal, fresh);
  const conflictCount = conflicts.ok ? Number.parseInt(conflicts.stdout.trim(), 10) || 0 : 0;
  const counts = Object.fromEntries(TASK_FLAGS.map((flag) => [flag, tasks.filter((task) => task.flag === flag).length]));
  const wip = tasks.filter((task) => task.flag === "wip");
  const issues: string[] = [];

  if (conflictCount > 0) issues.push(`${conflictCount} visible conflict revision(s)`);
  if (wip.length > 1) issues.push(`multiple [task:wip] revisions: ${wip.map((task) => task.changeId).join(", ")}`);
  if (tasks.length >= limit) issues.push(`task list hit limit ${limit}; increase limit for a complete check`);

  return { action: "check", ok: issues.length === 0, issues, counts, wip, conflictCount, limit };
}

function toolText(action: JjTodoAction, data: unknown): string {
  return `jj_todo ${action}:\n${JSON.stringify(data, null, 2)}`;
}

export default function jjTodoExtension(pi: ExtensionAPI) {
  pi.registerTool({
    name: "jj_todo",
    label: "JJ TODO",
    description: "Perform compact JJ TODO workflow operations: list task commits, find ready child tasks, create task commits, update task flags, and check task state.",
    promptSnippet: "Manage mechanical JJ TODO workflow operations with compact structured output.",
    promptGuidelines: [
      "Use jj_todo for routine JJ TODO mechanics such as listing tasks, creating task commits, and updating [task:*] flags; keep planning and task judgment in normal reasoning.",
      "Use jj_todo read actions before verbose jj shell commands when task state summaries are enough; use bash with jj for full graph inspection, rebases, splits, and unusual mutations.",
    ],
    parameters: jjTodoParams,

    async execute(_toolCallId, params: JjTodoParams, signal, _onUpdate, ctx) {
      const action = params.action;
      let data: unknown;

      if (action === "list") data = await listTasks(pi, ctx, signal, params);
      else if (action === "next") data = await nextTasks(pi, ctx, signal, params);
      else if (action === "create") data = await createTask(pi, ctx, signal, params);
      else if (action === "update") data = await updateTask(pi, ctx, signal, params);
      else if (action === "check") data = await checkTasks(pi, ctx, signal, params);
      else throw new Error(`unknown jj_todo action: ${action}`);

      return { content: [{ type: "text", text: toolText(action, data) }], details: data };
    },
  });
}
