import assert from "node:assert/strict";
import test from "node:test";
import type { Usage } from "@earendil-works/pi-ai";
import {
  claudePermissionOptions,
  DEFAULT_CLAUDE_PERMISSION_POLICY,
  resolveClaudePermissionPolicy,
} from "./src/backends/claude-permissions.ts";
import {
  createUsageLedger,
  sumPiSessionUsage,
  usageFromClaudeModelUsage,
} from "./src/usage.ts";

function usage(input: number, output: number, cost = 0): Usage {
  return {
    input,
    output,
    cacheRead: 0,
    cacheWrite: 0,
    cacheWrite1h: 0,
    reasoning: 0,
    totalTokens: input + output,
    cost: {
      input: 0,
      output: 0,
      cacheRead: 0,
      cacheWrite: 0,
      total: cost,
    },
  };
}

test("Claude permission policy has explicit precedence and a full default", () => {
  assert.equal(DEFAULT_CLAUDE_PERMISSION_POLICY, "full");
  assert.deepEqual(
    resolveClaudePermissionPolicy({
      flag: "plan",
      environment: "dontAsk",
      file: "acceptEdits",
    }),
    { policy: "plan", source: "flag" },
  );
  assert.deepEqual(
    resolveClaudePermissionPolicy({ environment: "dontAsk", file: "plan" }),
    { policy: "dontAsk", source: "environment" },
  );
  assert.deepEqual(resolveClaudePermissionPolicy({ file: "acceptEdits" }), {
    policy: "acceptEdits",
    source: "file",
  });
  assert.deepEqual(resolveClaudePermissionPolicy({}), {
    policy: "full",
    source: "default",
  });
  const lowerPrecedence = resolveClaudePermissionPolicy({
    flag: "invalid",
    file: "plan",
  });
  assert.equal(lowerPrecedence.policy, "plan");
  assert.equal(lowerPrecedence.source, "file");
  assert.match(lowerPrecedence.warning ?? "", /Invalid Claude subagent permission policy/);
  const failClosed = resolveClaudePermissionPolicy({ environment: "invalid" });
  assert.equal(failClosed.policy, "dontAsk");
  assert.match(failClosed.warning ?? "", /failing closed/);
});

test("dangerous permission skipping is enabled only for explicit full access", () => {
  assert.deepEqual(claudePermissionOptions("full"), {
    permissionMode: "bypassPermissions",
    allowDangerouslySkipPermissions: true,
  });
  assert.deepEqual(claudePermissionOptions("dontAsk"), {
    permissionMode: "dontAsk",
  });
  assert.deepEqual(claudePermissionOptions("acceptEdits"), {
    permissionMode: "acceptEdits",
  });
  assert.deepEqual(claudePermissionOptions("plan"), { permissionMode: "plan" });
});

test("Claude cumulative model usage is converted to Pi accounting", () => {
  const result = usageFromClaudeModelUsage(
    {
      opus: {
        inputTokens: 10,
        outputTokens: 20,
        cacheReadInputTokens: 30,
        cacheCreationInputTokens: 40,
        costUSD: 0.5,
      },
      haiku: {
        inputTokens: 1,
        outputTokens: 2,
        cacheReadInputTokens: 3,
        cacheCreationInputTokens: 4,
        costUSD: 0.1,
      },
    },
    0.75,
  );
  assert.deepEqual(
    {
      input: result.input,
      output: result.output,
      cacheRead: result.cacheRead,
      cacheWrite: result.cacheWrite,
      totalTokens: result.totalTokens,
      totalCost: result.cost.total,
    },
    {
      input: 11,
      output: 22,
      cacheRead: 33,
      cacheWrite: 44,
      totalTokens: 110,
      totalCost: 0.75,
    },
  );
});

test("Pi accounting includes assistant, tool, compaction, and branch usage", () => {
  const total = sumPiSessionUsage([
    { type: "message", message: { role: "assistant", usage: usage(1, 2) } },
    { type: "message", message: { role: "toolResult", usage: usage(3, 4) } },
    { type: "message", message: { role: "user" } },
    { type: "compaction", usage: usage(5, 6) },
    { type: "branch_summary", usage: usage(7, 8) },
  ] as unknown as Parameters<typeof sumPiSessionUsage>[0]);
  assert.equal(total.input, 16);
  assert.equal(total.output, 20);
  assert.equal(total.totalTokens, 36);
});

test("usage ledger reports cumulative child usage exactly once", () => {
  const ledger = createUsageLedger();
  ledger.recordCumulative("sa-1", usage(10, 5, 0.1));
  assert.deepEqual(ledger.drain(), usage(10, 5, 0.1));
  assert.equal(ledger.drain(), undefined);

  ledger.recordCumulative("sa-1", usage(14, 7, 0.15));
  ledger.recordCumulative("sa-2", usage(3, 2, 0.02));
  const combined = ledger.drain();
  assert.equal(combined?.input, 7);
  assert.equal(combined?.output, 4);
  assert.ok(Math.abs((combined?.cost.total ?? 0) - 0.07) < 1e-12);
  assert.equal(ledger.drain(), undefined);

  // A restarted native counter may reset; the new cumulative value is a delta.
  ledger.recordCumulative("sa-1", usage(2, 1, 0.01));
  assert.deepEqual(ledger.drain(), usage(2, 1, 0.01));
});
