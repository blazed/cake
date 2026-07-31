import { execFile } from "node:child_process";
import { mkdtemp, rm, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { promisify } from "node:util";
import assert from "node:assert/strict";
import test from "node:test";
import { visibleWidth } from "@earendil-works/pi-tui";
import { collectUsage, readJjInfo, renderExtensionStatuses } from "../extensions/footer/index.ts";
import { createQuotaTracker } from "../extensions/footer/quota-tracker.ts";
import { createWorkingTimerExtension } from "../extensions/working-timer/index.ts";

const execFileAsync = promisify(execFile);

async function tick(): Promise<void> {
  await new Promise<void>((resolve) => setImmediate(resolve));
}

async function runJj(cwd: string, args: string[]): Promise<string> {
  const { stdout } = await execFileAsync("jj", args, { cwd, encoding: "utf8" });
  return stdout;
}

test("quota failures are negative-cached until the refresh interval", async () => {
  let now = 1_000;
  let calls = 0;
  let intervalCallback: (() => void) | undefined;
  const tracker = createQuotaTracker(
    async () => {
      calls++;
      return null;
    },
    () => {},
    {
      refreshIntervalMs: 60_000,
      now: () => now,
      setInterval: ((callback: () => void) => {
        intervalCallback = callback;
        return 1 as never;
      }) as unknown as typeof globalThis.setInterval,
      clearInterval: (() => {}) as typeof globalThis.clearInterval,
    },
  );

  tracker.setEnabled(true);
  await tick();
  tracker.setEnabled(true);
  tracker.setEnabled(true);
  await tick();
  assert.equal(calls, 1);

  now += 59_999;
  tracker.setEnabled(true);
  await tick();
  assert.equal(calls, 1);

  now += 1;
  intervalCallback?.();
  await tick();
  assert.equal(calls, 2);
  tracker.dispose();
});

test("disposing a quota tracker aborts its active request", async () => {
  let observedSignal: AbortSignal | undefined;
  const tracker = createQuotaTracker(
    (signal) => {
      observedSignal = signal;
      return new Promise(() => {});
    },
    () => {},
    {
      setInterval: (() => 1 as never) as typeof globalThis.setInterval,
      clearInterval: (() => {}) as typeof globalThis.clearInterval,
    },
  );
  tracker.setEnabled(true);
  await tick();
  assert.equal(observedSignal?.aborted, false);
  tracker.dispose();
  assert.equal(observedSignal?.aborted, true);
});

test("a cancelled quota request cannot wedge a re-enabled tracker", async () => {
  const signals: AbortSignal[] = [];
  const resolveReads: Array<() => void> = [];
  let calls = 0;
  const tracker = createQuotaTracker(
    (signal) => {
      calls++;
      signals.push(signal);
      return new Promise<null>((resolve) => resolveReads.push(() => resolve(null)));
    },
    () => {},
    {
      setInterval: (() => 1 as never) as typeof globalThis.setInterval,
      clearInterval: (() => {}) as typeof globalThis.clearInterval,
    },
  );

  tracker.setEnabled(true);
  await tick();
  tracker.setEnabled(false);
  tracker.setEnabled(true);
  await tick();
  assert.equal(calls, 2);
  assert.equal(signals[0]?.aborted, true);
  assert.equal(signals[1]?.aborted, false);

  resolveReads[0]?.();
  resolveReads[1]?.();
  await tick();
  tracker.dispose();
});

test("footer usage includes assistant, tool, compaction, and branch-summary entries", () => {
  const usage = (input: number, output: number, cacheRead: number, cacheWrite: number, cost: number) => ({
    input,
    output,
    cacheRead,
    cacheWrite,
    cost: { total: cost },
  });
  const entries = [
    { type: "message", message: { role: "assistant", usage: usage(1, 2, 3, 4, 0.1) } },
    { type: "message", message: { role: "toolResult", usage: usage(5, 6, 7, 8, 0.2) } },
    { type: "compaction", usage: usage(9, 10, 11, 12, 0.3) },
    { type: "branch_summary", usage: usage(13, 14, 15, 16, 0.4) },
    {
      type: "custom",
      customType: "subagent-accounting",
      data: { usage: usage(17, 18, 19, 20, 0.5) },
    },
    { type: "message", message: { role: "user" } },
  ];
  const totals = collectUsage({ sessionManager: { getEntries: () => entries } } as never);
  assert.deepEqual(totals, {
    input: 45,
    output: 50,
    cacheRead: 55,
    cacheWrite: 60,
    cost: 1.5,
  });
});

test("extension statuses are sorted, sanitized, and width-bounded", () => {
  const statuses = new Map([
    ["z", "last\nline"],
    ["a", "first\tstatus"],
  ]);
  const rendered = renderExtensionStatuses(statuses, 80, "...");
  assert.equal(rendered, "first status last line");
  assert.equal(visibleWidth(renderExtensionStatuses(statuses, 10, "...") ?? ""), 10);
});

test("JJ footer snapshots filesystem edits and diffs the displayed revision", async () => {
  const cwd = await mkdtemp(join(tmpdir(), "footer-jj-test-"));
  try {
    await runJj(cwd, ["git", "init"]);
    await writeFile(join(cwd, "tracked.txt"), "line\n");

    const current = await readJjInfo(cwd);
    assert.equal(current?.revset, "@");
    assert.equal(current?.added, 1);

    await runJj(cwd, ["describe", "@", "-m", "parent"]);
    await runJj(cwd, ["new", "-m", "child"]);
    const parent = await readJjInfo(cwd);
    assert.equal(parent?.revset, "@-");
    assert.equal(parent?.added, 1);
  } finally {
    await rm(cwd, { recursive: true, force: true });
  }
});

test("JJ footer keeps an empty merge revision instead of mixing multiple parents", async () => {
  const cwd = await mkdtemp(join(tmpdir(), "footer-jj-merge-test-"));
  try {
    await runJj(cwd, ["git", "init"]);
    await runJj(cwd, ["new", "--no-edit", "@", "-m", "left"]);
    await runJj(cwd, ["new", "--no-edit", "@", "-m", "right"]);
    const children = (await runJj(cwd, [
      "log", "-r", "children(@)", "-G", "-T", 'change_id ++ "\\n"',
    ])).trim().split("\n");
    assert.equal(children.length, 2);
    await runJj(cwd, ["new", `change_id(${children[0]})`, `change_id(${children[1]})`, "-m", "merge"]);

    const merge = await readJjInfo(cwd);
    assert.equal(merge?.revset, "@");
  } finally {
    await rm(cwd, { recursive: true, force: true });
  }
});

test("working timer spans repeated agent starts, settles once, and never owns the title", () => {
  let now = 1_000;
  let intervalCallback: (() => void) | undefined;
  let titleWrites = 0;
  let clears = 0;
  const handlers = new Map<string, (event: unknown, ctx: any) => void>();
  const messages: Array<string | undefined> = [];
  const widgets = new Map<string, unknown>();
  const pi = {
    on(name: string, handler: (event: unknown, ctx: any) => void) {
      handlers.set(name, handler);
    },
  };
  const ctx = {
    mode: "tui",
    ui: {
      setWorkingMessage(message?: string) {
        messages.push(message);
      },
      setWidget(key: string, widget: unknown) {
        widgets.set(key, widget);
      },
      setTitle() {
        titleWrites++;
      },
    },
  };
  createWorkingTimerExtension({
    now: () => now,
    setInterval: ((callback: () => void) => {
      intervalCallback = callback;
      return 1 as never;
    }) as unknown as typeof globalThis.setInterval,
    clearInterval: (() => {
      clears++;
      intervalCallback = undefined;
    }) as typeof globalThis.clearInterval,
  })(pi as never);

  handlers.get("agent_start")?.({}, ctx);
  now = 5_000;
  handlers.get("agent_start")?.({}, ctx);
  intervalCallback?.();
  now = 7_000;
  handlers.get("agent_settled")?.({}, ctx);

  assert.equal(titleWrites, 0);
  assert.equal(messages.includes("Working... (4s)"), true);
  assert.equal(messages.at(-1), undefined);
  assert.equal(clears, 1);
  const widgetFactory = widgets.get("working-timer-summary") as (
    tui: unknown,
    theme: { fg: (_role: string, text: string) => string },
  ) => { render(width: number): string[] };
  const component = widgetFactory({}, { fg: (_role, text) => text });
  assert.deepEqual(component.render(80), ["Worked for 6s"]);

  now = 8_000;
  handlers.get("agent_start")?.({}, ctx);
  handlers.get("session_shutdown")?.({}, ctx);
  assert.equal(clears, 2);
  assert.equal(widgets.get("working-timer-summary"), undefined);
});

test("working timer ignores RPC mode", () => {
  let intervals = 0;
  let messages = 0;
  const handlers = new Map<string, (event: unknown, ctx: any) => void>();
  const pi = { on: (name: string, handler: (event: unknown, ctx: any) => void) => handlers.set(name, handler) };
  createWorkingTimerExtension({
    setInterval: (() => {
      intervals++;
      return 1 as never;
    }) as typeof globalThis.setInterval,
    clearInterval: (() => {}) as typeof globalThis.clearInterval,
  })(pi as never);
  handlers.get("agent_start")?.({}, {
    mode: "rpc",
    ui: { setWorkingMessage: () => messages++, setWidget: () => {} },
  });
  assert.equal(intervals, 0);
  assert.equal(messages, 0);
});
