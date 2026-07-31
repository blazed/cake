import { execFile } from "node:child_process";
import { mkdtemp, rm } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { promisify } from "node:util";
import assert from "node:assert/strict";
import test from "node:test";
import jjTodoExtension from "../extensions/jj-todo/index.ts";

const execFileAsync = promisify(execFile);

interface CapturedTool {
  execute(
    id: string,
    params: Record<string, unknown>,
    signal: AbortSignal | undefined,
    onUpdate: () => void,
    ctx: { cwd: string },
  ): Promise<{ details: any }>;
}

async function runJj(cwd: string, args: string[]): Promise<string> {
  const { stdout } = await execFileAsync("jj", args, { cwd, encoding: "utf8" });
  return stdout;
}

async function makeRepo(): Promise<string> {
  const cwd = await mkdtemp(join(tmpdir(), "jj-tools-test-"));
  await runJj(cwd, ["git", "init"]);
  return cwd;
}

function captureTool(): CapturedTool {
  let tool: CapturedTool | undefined;
  const pi = {
    registerTool(candidate: CapturedTool) {
      tool = candidate;
    },
    async exec(command: string, args: string[], options: { cwd: string; signal?: AbortSignal; timeout?: number }) {
      try {
        const result = await execFileAsync(command, args, {
          cwd: options.cwd,
          signal: options.signal,
          timeout: options.timeout,
          encoding: "utf8",
        });
        return { code: 0, stdout: result.stdout, stderr: result.stderr };
      } catch (error) {
        const failure = error as { code?: number | string; stdout?: string; stderr?: string };
        return {
          code: typeof failure.code === "number" ? failure.code : 1,
          stdout: failure.stdout ?? "",
          stderr: failure.stderr ?? String(error),
        };
      }
    },
  };
  jjTodoExtension(pi as never);
  assert.ok(tool);
  return tool;
}

async function execute(tool: CapturedTool, cwd: string, params: Record<string, unknown>): Promise<any> {
  return (await tool.execute("test", params, undefined, () => {}, { cwd })).details;
}

async function childChangeIds(cwd: string, rev: string): Promise<string[]> {
  const stdout = await runJj(cwd, [
    "log",
    "-r",
    `children(${rev})`,
    "-G",
    "-T",
    'change_id ++ "\\n"',
  ]);
  return stdout.trim().split("\n").filter(Boolean);
}

test("create defaults to preview and requires its one-use token", async () => {
  const cwd = await makeRepo();
  try {
    const tool = captureTool();
    const request = { action: "create", parent: "@", flag: "todo", title: "child" };
    const preview = await execute(tool, cwd, request);
    assert.equal(preview.dryRun, true);
    assert.equal(typeof preview.previewToken, "string");
    assert.deepEqual(await childChangeIds(cwd, "@"), []);

    await assert.rejects(
      execute(tool, cwd, { ...request, dryRun: false }),
      /requires previewToken/,
    );

    const applied = await execute(tool, cwd, {
      ...request,
      dryRun: false,
      previewToken: preview.previewToken,
    });
    assert.equal(applied.task.flag, "todo");
    assert.equal(applied.created, applied.revision.changeId);
    assert.equal((await childChangeIds(cwd, "@")).length, 1);

    await assert.rejects(
      execute(tool, cwd, {
        ...request,
        dryRun: false,
        previewToken: preview.previewToken,
      }),
      /invalid or expired/,
    );
  } finally {
    await rm(cwd, { recursive: true, force: true });
  }
});

test("mutation targets must resolve to exactly one revision", async () => {
  const cwd = await makeRepo();
  try {
    const tool = captureTool();
    await runJj(cwd, ["new", "--no-edit", "@", "-m", "one"]);
    await runJj(cwd, ["new", "--no-edit", "@", "-m", "two"]);

    await assert.rejects(
      execute(tool, cwd, { action: "create", parent: "children(@)", title: "merge" }),
      /resolved to 2 revisions/,
    );
    await assert.rejects(
      execute(tool, cwd, { action: "update", rev: "children(@)", flag: "done" }),
      /resolved to 2 revisions/,
    );
    await assert.rejects(
      execute(tool, cwd, { action: "create", parent: "@", flag: "done", title: "invalid" }),
      /only draft or todo/,
    );
  } finally {
    await rm(cwd, { recursive: true, force: true });
  }
});

test("repository mutations invalidate preview tokens", async () => {
  const cwd = await makeRepo();
  try {
    const tool = captureTool();
    await runJj(cwd, ["describe", "@", "-m", "[task:todo] root"]);
    const request = { action: "update", rev: "@", flag: "done" };
    const preview = await execute(tool, cwd, request);
    await runJj(cwd, ["describe", "@", "-m", "[task:review] changed elsewhere"]);

    await assert.rejects(
      execute(tool, cwd, {
        ...request,
        dryRun: false,
        previewToken: preview.previewToken,
      }),
      /repository changed after preview/,
    );
  } finally {
    await rm(cwd, { recursive: true, force: true });
  }
});

test("update applies to the exact previewed revision and returns its rewritten identity", async () => {
  const cwd = await makeRepo();
  try {
    const tool = captureTool();
    await runJj(cwd, ["describe", "@", "-m", "[task:todo] root"]);
    const request = { action: "update", rev: "@", flag: "done" };
    const preview = await execute(tool, cwd, request);
    const applied = await execute(tool, cwd, {
      ...request,
      dryRun: false,
      previewToken: preview.previewToken,
    });

    assert.equal(applied.task.flag, "done");
    assert.equal(applied.resolvedRevision.changeId, preview.resolvedRevision.changeId);
    assert.notEqual(applied.resolvedRevision.commitId, preview.resolvedRevision.commitId);
  } finally {
    await rm(cwd, { recursive: true, force: true });
  }
});

test("unsupported task flags are reported and cannot be silently prefixed", async () => {
  const cwd = await makeRepo();
  try {
    const tool = captureTool();
    await runJj(cwd, ["describe", "@", "-m", "[task:inprogress] root"]);

    await assert.rejects(
      execute(tool, cwd, { action: "update", rev: "@", flag: "done" }),
      /unsupported task flag/,
    );
    const check = await execute(tool, cwd, { action: "check" });
    assert.equal(check.ok, false);
    assert.equal(check.invalidTasks[0].flag, "inprogress");
  } finally {
    await rm(cwd, { recursive: true, force: true });
  }
});

test("next requires todo children and every task ancestor to be done", async () => {
  const cwd = await makeRepo();
  try {
    const tool = captureTool();
    await runJj(cwd, ["describe", "@", "-m", "[task:standby] root"]);
    await runJj(cwd, ["new", "--no-edit", "@", "-m", "[task:done] middle"]);
    const [middle] = await childChangeIds(cwd, "@");
    assert.ok(middle);
    await runJj(cwd, ["new", "--no-edit", `change_id(${middle})`, "-m", "[task:todo] leaf"]);
    await runJj(cwd, ["new", "--no-edit", `change_id(${middle})`, "-m", "[task:wip] already running"]);

    const state = await execute(tool, cwd, { action: "next", rev: `change_id(${middle})` });
    assert.equal(state.ready.length, 0);
    assert.equal(state.blocked.length, 1);
    assert.equal(state.blocked[0].blockedBy.some((task: { flag: string }) => task.flag === "standby"), true);
    assert.equal(state.notReady.length, 1);
    assert.equal(state.notReady[0].flag, "wip");
  } finally {
    await rm(cwd, { recursive: true, force: true });
  }
});
