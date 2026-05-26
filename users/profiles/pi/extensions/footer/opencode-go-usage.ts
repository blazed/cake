/**
 * OpenCode Go usage quota tracker.
 *
 * Prefers the API-key endpoint proposed upstream (`/zen/go/v1/usage`) and falls
 * back to scraping the Go dashboard when OPENCODE_GO_WORKSPACE_ID and
 * OPENCODE_GO_AUTH_COOKIE are configured.
 */

import { readFile } from "node:fs/promises";
import { homedir } from "node:os";
import { join } from "node:path";
import type { ExtensionContext } from "@earendil-works/pi-coding-agent";
import type { QuotaSnapshot, QuotaTracker, QuotaWindowSnapshot } from "./codex-usage.ts";

interface OpenCodeGoUsageWindow {
  usagePercent?: unknown;
  resetInSec?: unknown;
}

interface OpenCodeGoUsageResponse {
  rollingUsage?: OpenCodeGoUsageWindow;
  weeklyUsage?: OpenCodeGoUsageWindow;
  monthlyUsage?: OpenCodeGoUsageWindow;
}

interface OpenCodeGoDashboardConfig {
  workspaceId: string;
  authCookie: string;
}

interface ScrapedWindowUsage {
  usagePercent: number;
  resetInSec: number;
}

const OPENCODE_GO_BASE_URL = (
  process.env.OPENCODE_GO_BASE_URL || "https://opencode.ai/zen/go/v1"
).replace(/\/+$/, "");
const DASHBOARD_URL_PREFIX = "https://opencode.ai/workspace/";
const DASHBOARD_URL_SUFFIX = "/go";
const REFRESH_INTERVAL_MS = 60_000;
const REQUEST_TIMEOUT_MS = 15_000;

const ROLLING_WINDOW_MINS = 5 * 60;
const WEEKLY_WINDOW_MINS = 7 * 24 * 60;
const MONTHLY_WINDOW_MINS = 30 * 24 * 60;

const SCRAPED_NUMBER_PATTERN = String.raw`(-?\d+(?:\.\d+)?)`;
const RE_ROLLING_PCT_FIRST = new RegExp(
  String.raw`rollingUsage:\$R\[\d+\]=\{[^}]*usagePercent:${SCRAPED_NUMBER_PATTERN}[^}]*resetInSec:${SCRAPED_NUMBER_PATTERN}[^}]*\}`,
);
const RE_ROLLING_RESET_FIRST = new RegExp(
  String.raw`rollingUsage:\$R\[\d+\]=\{[^}]*resetInSec:${SCRAPED_NUMBER_PATTERN}[^}]*usagePercent:${SCRAPED_NUMBER_PATTERN}[^}]*\}`,
);
const RE_WEEKLY_PCT_FIRST = new RegExp(
  String.raw`weeklyUsage:\$R\[\d+\]=\{[^}]*usagePercent:${SCRAPED_NUMBER_PATTERN}[^}]*resetInSec:${SCRAPED_NUMBER_PATTERN}[^}]*\}`,
);
const RE_WEEKLY_RESET_FIRST = new RegExp(
  String.raw`weeklyUsage:\$R\[\d+\]=\{[^}]*resetInSec:${SCRAPED_NUMBER_PATTERN}[^}]*usagePercent:${SCRAPED_NUMBER_PATTERN}[^}]*\}`,
);
const RE_MONTHLY_PCT_FIRST = new RegExp(
  String.raw`monthlyUsage:\$R\[\d+\]=\{[^}]*usagePercent:${SCRAPED_NUMBER_PATTERN}[^}]*resetInSec:${SCRAPED_NUMBER_PATTERN}[^}]*\}`,
);
const RE_MONTHLY_RESET_FIRST = new RegExp(
  String.raw`monthlyUsage:\$R\[\d+\]=\{[^}]*resetInSec:${SCRAPED_NUMBER_PATTERN}[^}]*usagePercent:${SCRAPED_NUMBER_PATTERN}[^}]*\}`,
);

function timeoutSignal(timeoutMs: number): { signal: AbortSignal; cancel: () => void } {
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), timeoutMs);
  return {
    signal: controller.signal,
    cancel: () => clearTimeout(timeout),
  };
}

function normalizeWindow(
  window: OpenCodeGoUsageWindow | undefined,
  windowDurationMins: number,
): QuotaWindowSnapshot | null {
  if (!window || typeof window !== "object") return null;
  if (typeof window.usagePercent !== "number") return null;

  const resetInSec = typeof window.resetInSec === "number" ? window.resetInSec : null;
  return {
    usedPercent: Math.max(0, Math.min(100, window.usagePercent)),
    windowDurationMins,
    resetsAt: resetInSec === null ? null : Date.now() + Math.max(0, resetInSec) * 1000,
  };
}

function extractQuotaSnapshot(payload: OpenCodeGoUsageResponse): QuotaSnapshot | null {
  const rolling = normalizeWindow(payload.rollingUsage, ROLLING_WINDOW_MINS);
  const weekly = normalizeWindow(payload.weeklyUsage, WEEKLY_WINDOW_MINS);
  const monthly = normalizeWindow(payload.monthlyUsage, MONTHLY_WINDOW_MINS);
  if (!rolling && !weekly && !monthly) return null;

  return {
    limitId: "opencode-go",
    limitName: "OpenCode Go",
    primary: rolling,
    secondary: weekly,
    tertiary: monthly,
  };
}

async function readOfficialUsageEndpoint(ctx: ExtensionContext): Promise<QuotaSnapshot | null> {
  const model = ctx.model;
  if (!model) return null;

  const auth = await ctx.modelRegistry.getApiKeyAndHeaders(model);
  if (!auth.ok || !auth.apiKey) return null;

  const headers = new Headers(auth.headers);
  headers.set("Authorization", `Bearer ${auth.apiKey}`);
  headers.set("Accept", "application/json");
  headers.set("User-Agent", "cake-footer");

  const timeout = timeoutSignal(REQUEST_TIMEOUT_MS);
  try {
    const response = await fetch(`${OPENCODE_GO_BASE_URL}/usage`, {
      headers,
      signal: timeout.signal,
    });
    if (!response.ok) return null;
    return extractQuotaSnapshot((await response.json()) as OpenCodeGoUsageResponse);
  } catch {
    return null;
  } finally {
    timeout.cancel();
  }
}

async function readDashboardConfig(): Promise<OpenCodeGoDashboardConfig | null> {
  const workspaceId = process.env.OPENCODE_GO_WORKSPACE_ID?.trim();
  const authCookie = process.env.OPENCODE_GO_AUTH_COOKIE?.trim();
  if (workspaceId && authCookie) return { workspaceId, authCookie };

  try {
    const configPath = join(homedir(), ".config", "opencode", "opencode-quota", "opencode-go.json");
    const parsed = JSON.parse(await readFile(configPath, "utf8")) as Record<string, unknown>;
    const fileWorkspaceId = typeof parsed.workspaceId === "string" ? parsed.workspaceId.trim() : "";
    const fileAuthCookie = typeof parsed.authCookie === "string" ? parsed.authCookie.trim() : "";
    if (fileWorkspaceId && fileAuthCookie) {
      return { workspaceId: fileWorkspaceId, authCookie: fileAuthCookie };
    }
  } catch {
    // No dashboard config; official API-key endpoint may still work in the future.
  }

  return null;
}

function parseWindowUsage(
  html: string,
  rePctFirst: RegExp,
  reResetFirst: RegExp,
): ScrapedWindowUsage | null {
  const pctFirstMatch = rePctFirst.exec(html);
  if (pctFirstMatch) {
    const usagePercent = Number(pctFirstMatch[1]);
    const resetInSec = Number(pctFirstMatch[2]);
    if (Number.isFinite(usagePercent) && Number.isFinite(resetInSec)) {
      return { usagePercent, resetInSec };
    }
  }

  const resetFirstMatch = reResetFirst.exec(html);
  if (resetFirstMatch) {
    const resetInSec = Number(resetFirstMatch[1]);
    const usagePercent = Number(resetFirstMatch[2]);
    if (Number.isFinite(usagePercent) && Number.isFinite(resetInSec)) {
      return { usagePercent, resetInSec };
    }
  }

  return null;
}

function scrapedWindowToUsage(window: ScrapedWindowUsage | null): OpenCodeGoUsageWindow | undefined {
  if (!window) return undefined;
  return {
    usagePercent: window.usagePercent,
    resetInSec: window.resetInSec,
  };
}

async function readDashboardUsage(): Promise<QuotaSnapshot | null> {
  const config = await readDashboardConfig();
  if (!config) return null;

  const timeout = timeoutSignal(REQUEST_TIMEOUT_MS);
  try {
    const response = await fetch(
      `${DASHBOARD_URL_PREFIX}${encodeURIComponent(config.workspaceId)}${DASHBOARD_URL_SUFFIX}`,
      {
        headers: {
          Accept: "text/html",
          Cookie: `auth=${config.authCookie}`,
          "User-Agent": "Mozilla/5.0 cake-footer",
        },
        signal: timeout.signal,
      },
    );
    if (!response.ok) return null;

    const html = await response.text();
    return extractQuotaSnapshot({
      rollingUsage: scrapedWindowToUsage(
        parseWindowUsage(html, RE_ROLLING_PCT_FIRST, RE_ROLLING_RESET_FIRST),
      ),
      weeklyUsage: scrapedWindowToUsage(
        parseWindowUsage(html, RE_WEEKLY_PCT_FIRST, RE_WEEKLY_RESET_FIRST),
      ),
      monthlyUsage: scrapedWindowToUsage(
        parseWindowUsage(html, RE_MONTHLY_PCT_FIRST, RE_MONTHLY_RESET_FIRST),
      ),
    });
  } catch {
    return null;
  } finally {
    timeout.cancel();
  }
}

async function readOpenCodeGoQuotaSnapshot(ctx: ExtensionContext): Promise<QuotaSnapshot | null> {
  return (await readOfficialUsageEndpoint(ctx)) ?? (await readDashboardUsage());
}

export function createOpenCodeGoQuotaTracker(
  ctx: ExtensionContext,
  onUpdate: () => void,
): QuotaTracker {
  let enabled = false;
  let snapshot: QuotaSnapshot | null = null;
  let lastRefreshAt = 0;
  let refreshInFlight: Promise<void> | null = null;
  let interval: ReturnType<typeof setInterval> | null = null;
  let disposed = false;

  const refresh = async (): Promise<void> => {
    if (disposed || refreshInFlight) return;

    refreshInFlight = (async () => {
      const next = await readOpenCodeGoQuotaSnapshot(ctx);
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
