/**
 * ChatGPT Codex usage quota tracker.
 */

import type { ExtensionContext } from "@earendil-works/pi-coding-agent";
import {
  createQuotaTracker,
  type QuotaSnapshot,
  type QuotaTracker,
  type QuotaWindowSnapshot,
} from "./quota-tracker.ts";

export type { QuotaSnapshot, QuotaTracker, QuotaWindowSnapshot } from "./quota-tracker.ts";

interface ChatGptUsageWindow {
  used_percent?: unknown;
  limit_window_seconds?: unknown;
  reset_at?: unknown;
}

interface ChatGptUsageResponse {
  rate_limit?: {
    primary_window?: ChatGptUsageWindow;
    secondary_window?: ChatGptUsageWindow;
  };
}

const CHATGPT_BASE_URL = (
  process.env.CHATGPT_BASE_URL || "https://chatgpt.com/backend-api"
).replace(/\/+$/, "");
const OPENAI_AUTH_CLAIM = "https://api.openai.com/auth";
const REQUEST_TIMEOUT_MS = 15_000;

function decodeJwtPayload(token: string): Record<string, unknown> {
  const parts = token.split(".");
  if (parts.length < 2) return {};

  try {
    const decoded = Buffer.from(parts[1], "base64url").toString("utf8");
    const payload = JSON.parse(decoded) as unknown;
    return payload && typeof payload === "object" && !Array.isArray(payload)
      ? (payload as Record<string, unknown>)
      : {};
  } catch {
    return {};
  }
}

function extractChatGptAccountId(token: string): string | undefined {
  const payload = decodeJwtPayload(token);
  const auth = payload[OPENAI_AUTH_CLAIM];
  if (!auth || typeof auth !== "object" || Array.isArray(auth)) return undefined;

  const accountId = (auth as Record<string, unknown>).chatgpt_account_id;
  return typeof accountId === "string" && accountId.length > 0 ? accountId : undefined;
}

function normalizeWindow(window: ChatGptUsageWindow | undefined): QuotaWindowSnapshot | null {
  if (!window || typeof window !== "object") return null;
  if (typeof window.used_percent !== "number") return null;

  const durationSeconds =
    typeof window.limit_window_seconds === "number" ? window.limit_window_seconds : null;
  const resetSeconds = typeof window.reset_at === "number" ? window.reset_at : null;

  return {
    usedPercent: window.used_percent,
    windowDurationMins: durationSeconds === null ? null : Math.round(durationSeconds / 60),
    resetsAt: resetSeconds === null ? null : resetSeconds * 1000,
  };
}

function extractQuotaSnapshot(payload: ChatGptUsageResponse): QuotaSnapshot | null {
  const rateLimit = payload.rate_limit;
  if (!rateLimit || typeof rateLimit !== "object") return null;

  const primary = normalizeWindow(rateLimit.primary_window);
  const secondary = normalizeWindow(rateLimit.secondary_window);
  if (!primary && !secondary) return null;

  return {
    limitId: "codex",
    limitName: "OpenAI",
    primary,
    secondary,
  };
}

function timeoutSignal(timeoutMs: number, parentSignal: AbortSignal): { signal: AbortSignal; cancel: () => void } {
  const controller = new AbortController();
  const onParentAbort = () => controller.abort();
  if (parentSignal.aborted) controller.abort();
  else parentSignal.addEventListener("abort", onParentAbort, { once: true });
  const timeout = setTimeout(() => controller.abort(), timeoutMs);
  return {
    signal: controller.signal,
    cancel: () => {
      clearTimeout(timeout);
      parentSignal.removeEventListener("abort", onParentAbort);
    },
  };
}

async function readCodexQuotaSnapshot(ctx: ExtensionContext, signal: AbortSignal): Promise<QuotaSnapshot | null> {
  const model = ctx.model;
  if (!model) return null;

  const auth = await ctx.modelRegistry.getApiKeyAndHeaders(model);
  if (!auth.ok || !auth.apiKey) return null;

  const headers = new Headers(
    Object.entries(auth.headers ?? {}).filter((e): e is [string, string] => e[1] !== null),
  );
  headers.set("Authorization", `Bearer ${auth.apiKey}`);
  headers.set("Accept", "application/json");
  headers.set("User-Agent", "cake-footer");

  const accountId = extractChatGptAccountId(auth.apiKey);
  if (accountId) {
    headers.set("chatgpt-account-id", accountId);
  }

  const timeout = timeoutSignal(REQUEST_TIMEOUT_MS, signal);
  try {
    const response = await fetch(`${CHATGPT_BASE_URL}/wham/usage`, {
      headers,
      signal: timeout.signal,
    });
    if (!response.ok) return null;
    return extractQuotaSnapshot((await response.json()) as ChatGptUsageResponse);
  } catch {
    return null;
  } finally {
    timeout.cancel();
  }
}

export function createCodexQuotaTracker(ctx: ExtensionContext, onUpdate: () => void): QuotaTracker {
  return createQuotaTracker((signal) => readCodexQuotaSnapshot(ctx, signal), onUpdate);
}
