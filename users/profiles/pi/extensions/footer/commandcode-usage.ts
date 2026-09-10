/**
 * Command Code usage quota tracker.
 *
 * Reads the account's rolling 5-hour and weekly credit windows from the
 * Command Code alpha billing endpoints — the same source as the
 * `pi-commandcode-provider` `/commandcode-quota` command.
 */

import type { ExtensionContext } from "@earendil-works/pi-coding-agent";
import {
  createQuotaTracker,
  timeoutSignal,
  type QuotaSnapshot,
  type QuotaTracker,
  type QuotaWindowSnapshot,
} from "./quota-tracker.ts";

export type { QuotaSnapshot, QuotaTracker, QuotaWindowSnapshot } from "./quota-tracker.ts";

interface CommandCodeWindowLimit {
  used?: unknown;
  cap?: unknown;
  resetAt?: unknown;
}

interface CommandCodeCreditsResponse {
  windowLimits?: {
    fiveHour?: CommandCodeWindowLimit;
    weekly?: CommandCodeWindowLimit;
  };
}

const COMMAND_CODE_BASE_URL = (
  process.env.COMMANDCODE_API_BASE?.replace(/\/provider\/v1\/?$/, "") ||
  "https://api.commandcode.ai"
).replace(/\/+$/, "");
const REQUEST_TIMEOUT_MS = 15_000;

const WINDOW_DURATION_MINS = { fiveHour: 5 * 60, weekly: 7 * 24 * 60 } as const;

/** The alpha API reports reset times as unix seconds. */
function normalizeResetsAt(value: unknown): number | null {
  if (typeof value !== "number" || !Number.isFinite(value) || value <= 0) return null;
  return value >= 1e12 ? Math.round(value) : Math.round(value * 1000);
}

function normalizeWindow(
  window: CommandCodeWindowLimit | undefined,
  windowDurationMins: number,
): QuotaWindowSnapshot | null {
  if (!window || typeof window !== "object") return null;
  const used = typeof window.used === "number" ? window.used : null;
  const cap = typeof window.cap === "number" ? window.cap : null;
  if (used === null || cap === null || cap <= 0) return null;

  return {
    usedPercent: Math.max(0, Math.min(100, (used / cap) * 100)),
    windowDurationMins,
    resetsAt: normalizeResetsAt(window.resetAt),
  };
}

/** Map a `/alpha/billing/credits` payload onto the shared quota snapshot shape. */
export function parseCommandCodeSnapshot(payload: unknown): QuotaSnapshot | null {
  if (!payload || typeof payload !== "object" || Array.isArray(payload)) return null;
  const windowLimits = (payload as CommandCodeCreditsResponse).windowLimits;
  if (!windowLimits || typeof windowLimits !== "object") return null;

  const primary = normalizeWindow(windowLimits.fiveHour, WINDOW_DURATION_MINS.fiveHour);
  const secondary = normalizeWindow(windowLimits.weekly, WINDOW_DURATION_MINS.weekly);
  if (!primary && !secondary) return null;

  return { limitId: "commandcode", limitName: "Command Code", primary, secondary };
}

/** Org-scoped keys only report usage when the credits request carries the org id. */
async function readOrgId(
  headers: Record<string, string>,
  signal: AbortSignal,
): Promise<string | undefined> {
  try {
    const response = await fetch(`${COMMAND_CODE_BASE_URL}/alpha/whoami`, { headers, signal });
    if (!response.ok) return undefined;
    const payload = (await response.json()) as { org?: { id?: unknown } };
    const id = payload?.org?.id;
    return typeof id === "string" && id.length > 0 ? id : undefined;
  } catch {
    return undefined;
  }
}

async function readCommandCodeQuotaSnapshot(
  ctx: ExtensionContext,
  signal: AbortSignal,
): Promise<QuotaSnapshot | null> {
  const apiKey = await ctx.modelRegistry.getApiKeyForProvider("commandcode");
  if (!apiKey) return null;

  const timeout = timeoutSignal(REQUEST_TIMEOUT_MS, signal);
  try {
    const headers = { accept: "application/json", Authorization: `Bearer ${apiKey}` };
    const orgId = await readOrgId(headers, timeout.signal);
    const query = orgId ? `?orgId=${encodeURIComponent(orgId)}` : "";

    const response = await fetch(`${COMMAND_CODE_BASE_URL}/alpha/billing/credits${query}`, {
      headers,
      signal: timeout.signal,
    });
    if (!response.ok) return null;
    return parseCommandCodeSnapshot(await response.json());
  } catch {
    return null;
  } finally {
    timeout.cancel();
  }
}

export function createCommandCodeQuotaTracker(
  ctx: ExtensionContext,
  onUpdate: () => void,
): QuotaTracker {
  return createQuotaTracker((signal) => readCommandCodeQuotaSnapshot(ctx, signal), onUpdate);
}
