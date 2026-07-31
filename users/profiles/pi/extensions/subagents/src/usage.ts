import type { Usage } from "@earendil-works/pi-ai";
import type { SessionEntry } from "@earendil-works/pi-coding-agent";

export const ZERO_USAGE: Usage = {
  input: 0,
  output: 0,
  cacheRead: 0,
  cacheWrite: 0,
  totalTokens: 0,
  cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0, total: 0 },
};

export function addUsage(left: Usage | undefined, right: Usage | undefined): Usage {
  const a = left ?? ZERO_USAGE;
  const b = right ?? ZERO_USAGE;
  return {
    input: a.input + b.input,
    output: a.output + b.output,
    cacheRead: a.cacheRead + b.cacheRead,
    cacheWrite: a.cacheWrite + b.cacheWrite,
    cacheWrite1h: (a.cacheWrite1h ?? 0) + (b.cacheWrite1h ?? 0),
    reasoning: (a.reasoning ?? 0) + (b.reasoning ?? 0),
    totalTokens: a.totalTokens + b.totalTokens,
    cost: {
      input: a.cost.input + b.cost.input,
      output: a.cost.output + b.cost.output,
      cacheRead: a.cost.cacheRead + b.cost.cacheRead,
      cacheWrite: a.cost.cacheWrite + b.cost.cacheWrite,
      total: a.cost.total + b.cost.total,
    },
  };
}

export function isZeroUsage(usage: Usage | undefined): boolean {
  if (!usage) return true;
  return usage.totalTokens <= 0 && usage.cost.total <= 0;
}

function usageReset(current: Usage, previous: Usage): boolean {
  return (
    current.input < previous.input ||
    current.output < previous.output ||
    current.cacheRead < previous.cacheRead ||
    current.cacheWrite < previous.cacheWrite ||
    current.cost.total < previous.cost.total
  );
}

export function subtractUsage(current: Usage, previous: Usage | undefined): Usage {
  if (!previous || usageReset(current, previous)) return current;
  const subtract = (left: number, right: number) => Math.max(0, left - right);
  return {
    input: subtract(current.input, previous.input),
    output: subtract(current.output, previous.output),
    cacheRead: subtract(current.cacheRead, previous.cacheRead),
    cacheWrite: subtract(current.cacheWrite, previous.cacheWrite),
    cacheWrite1h: subtract(current.cacheWrite1h ?? 0, previous.cacheWrite1h ?? 0),
    reasoning: subtract(current.reasoning ?? 0, previous.reasoning ?? 0),
    totalTokens: subtract(current.totalTokens, previous.totalTokens),
    cost: {
      input: subtract(current.cost.input, previous.cost.input),
      output: subtract(current.cost.output, previous.cost.output),
      cacheRead: subtract(current.cost.cacheRead, previous.cost.cacheRead),
      cacheWrite: subtract(current.cost.cacheWrite, previous.cost.cacheWrite),
      total: subtract(current.cost.total, previous.cost.total),
    },
  };
}

export function sumPiSessionUsage(entries: ReadonlyArray<SessionEntry>): Usage {
  let total = ZERO_USAGE;
  for (const entry of entries) {
    let usage: Usage | undefined;
    if (entry.type === "message") {
      const message = entry.message as { role?: string; usage?: Usage };
      if (message.role === "assistant" || message.role === "toolResult") usage = message.usage;
    } else if (entry.type === "compaction" || entry.type === "branch_summary") {
      usage = entry.usage;
    }
    total = addUsage(total, usage);
  }
  return total;
}

export interface ClaudeModelUsage {
  inputTokens: number;
  outputTokens: number;
  cacheReadInputTokens: number;
  cacheCreationInputTokens: number;
  costUSD: number;
}

export function usageFromClaudeModelUsage(
  modelUsage: Readonly<Record<string, ClaudeModelUsage>>,
  totalCostUsd?: number,
): Usage {
  let input = 0;
  let output = 0;
  let cacheRead = 0;
  let cacheWrite = 0;
  let modelCost = 0;
  for (const usage of Object.values(modelUsage)) {
    input += usage.inputTokens;
    output += usage.outputTokens;
    cacheRead += usage.cacheReadInputTokens;
    cacheWrite += usage.cacheCreationInputTokens;
    modelCost += usage.costUSD;
  }
  return {
    input,
    output,
    cacheRead,
    cacheWrite,
    totalTokens: input + output + cacheRead + cacheWrite,
    // Claude exposes only aggregate/model cost, not the four pricing buckets.
    cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0, total: totalCostUsd ?? modelCost },
  };
}

export function createUsageLedger(maxEntries = 64) {
  const reported = new Map<string, Usage>();
  let pending = ZERO_USAGE;

  return {
    recordCumulative(id: string, cumulative: Usage | undefined): void {
      if (!cumulative) return;
      const delta = subtractUsage(cumulative, reported.get(id));
      reported.delete(id);
      reported.set(id, cumulative);
      if (!isZeroUsage(delta)) pending = addUsage(pending, delta);
      while (reported.size > maxEntries) {
        const oldest = reported.keys().next().value as string | undefined;
        if (!oldest) break;
        reported.delete(oldest);
      }
    },
    drain(): Usage | undefined {
      if (isZeroUsage(pending)) return undefined;
      const usage = pending;
      pending = ZERO_USAGE;
      return usage;
    },
    clear(): void {
      reported.clear();
      pending = ZERO_USAGE;
    },
  };
}
