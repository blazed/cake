/**
 * ChatGPT Codex usage quota tracker.
 */

import type { ExtensionContext } from "@earendil-works/pi-coding-agent";

export interface QuotaWindowSnapshot {
  usedPercent: number;
  windowDurationMins: number | null;
  resetsAt: number | null;
}

export interface QuotaSnapshot {
  limitId: string | null;
  limitName: string | null;
  primary: QuotaWindowSnapshot | null;
  secondary: QuotaWindowSnapshot | null;
  tertiary?: QuotaWindowSnapshot | null;
}

export interface QuotaTracker {
  setEnabled: (enabled: boolean) => void;
  getSnapshot: () => QuotaSnapshot | null;
  dispose: () => void;
}

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
const REFRESH_INTERVAL_MS = 60_000;
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

function timeoutSignal(timeoutMs: number): { signal: AbortSignal; cancel: () => void } {
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), timeoutMs);
  return {
    signal: controller.signal,
    cancel: () => clearTimeout(timeout),
  };
}

async function readCodexQuotaSnapshot(ctx: ExtensionContext): Promise<QuotaSnapshot | null> {
  const model = ctx.model;
  if (!model) return null;

  const auth = await ctx.modelRegistry.getApiKeyAndHeaders(model);
  if (!auth.ok || !auth.apiKey) return null;

  const headers = new Headers(auth.headers);
  headers.set("Authorization", `Bearer ${auth.apiKey}`);
  headers.set("Accept", "application/json");
  headers.set("User-Agent", "cake-footer");

  const accountId = extractChatGptAccountId(auth.apiKey);
  if (accountId) {
    headers.set("chatgpt-account-id", accountId);
  }

  const timeout = timeoutSignal(REQUEST_TIMEOUT_MS);
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
  let enabled = false;
  let snapshot: QuotaSnapshot | null = null;
  let lastRefreshAt = 0;
  let refreshInFlight: Promise<void> | null = null;
  let interval: ReturnType<typeof setInterval> | null = null;
  let disposed = false;

  const refresh = async (): Promise<void> => {
    if (disposed || refreshInFlight) return;

    refreshInFlight = (async () => {
      const next = await readCodexQuotaSnapshot(ctx);
      const previous = snapshot ? JSON.stringify(snapshot) : null;
      const current = next ? JSON.stringify(next) : null;
      snapshot = next;
      lastRefreshAt = Date.now();
      if (previous !== current) {
        onUpdate();
      }
    })().finally(() => {
      refreshInFlight = null;
    });

    await refreshInFlight;
  };

  const stopInterval = (): void => {
    if (interval) {
      clearInterval(interval);
      interval = null;
    }
  };

  const startInterval = (): void => {
    if (interval) return;
    interval = setInterval(() => {
      void refresh();
    }, REFRESH_INTERVAL_MS);
  };

  return {
    setEnabled(nextEnabled: boolean): void {
      enabled = nextEnabled;
      if (!enabled) {
        stopInterval();
        return;
      }

      startInterval();
      if (!snapshot || Date.now() - lastRefreshAt >= REFRESH_INTERVAL_MS) {
        void refresh();
      }
    },
    getSnapshot(): QuotaSnapshot | null {
      return snapshot;
    },
    dispose(): void {
      disposed = true;
      stopInterval();
    },
  };
}
