/**
 * Working timer extension for Pi.
 *
 * Adds elapsed time to the TUI working message without taking ownership of the
 * terminal title, which may be managed by remote-pi or another integration.
 */

import type { ExtensionAPI, ExtensionContext, Theme } from "@earendil-works/pi-coding-agent";
import { truncateToWidth, type Component, type TUI } from "@earendil-works/pi-tui";

const SUMMARY_WIDGET_KEY = "working-timer-summary";

export interface WorkingTimerDependencies {
  now?: () => number;
  setInterval?: typeof globalThis.setInterval;
  clearInterval?: typeof globalThis.clearInterval;
}

export function formatElapsed(elapsedMs: number): string {
  const totalSeconds = Math.max(0, Math.floor(elapsedMs / 1000));
  const seconds = totalSeconds % 60;
  const totalMinutes = Math.floor(totalSeconds / 60);
  const minutes = totalMinutes % 60;
  const hours = Math.floor(totalMinutes / 60);

  if (hours > 0) return `${hours}h ${minutes}m ${seconds}s`;
  if (totalMinutes > 0) return `${totalMinutes}m ${seconds}s`;
  return `${seconds}s`;
}

export function createWorkingTimerExtension(dependencies: WorkingTimerDependencies = {}) {
  const now = dependencies.now ?? Date.now;
  const startTimer = dependencies.setInterval ?? globalThis.setInterval;
  const stopTimer = dependencies.clearInterval ?? globalThis.clearInterval;
  let startedAt: number | null = null;
  let messageTimer: ReturnType<typeof setInterval> | null = null;

  const clearTimer = (): void => {
    if (messageTimer !== null) {
      stopTimer(messageTimer);
      messageTimer = null;
    }
  };

  const setMessage = (ctx: ExtensionContext): void => {
    if (ctx.mode !== "tui" || startedAt === null) return;
    ctx.ui.setWorkingMessage(`Working... (${formatElapsed(now() - startedAt)})`);
  };

  const setWorkedSummary = (ctx: ExtensionContext, elapsedMs: number): void => {
    const label = `Worked for ${formatElapsed(elapsedMs)}`;
    ctx.ui.setWidget(SUMMARY_WIDGET_KEY, (_tui: TUI, theme: Theme): Component => ({
      render(width: number) {
        return [truncateToWidth(theme.fg("muted", label), width)];
      },
      invalidate() {},
    }));
  };

  const start = (ctx: ExtensionContext): void => {
    if (ctx.mode !== "tui") return;
    if (startedAt !== null) {
      setMessage(ctx);
      return;
    }

    ctx.ui.setWidget(SUMMARY_WIDGET_KEY, undefined);
    startedAt = now();
    setMessage(ctx);
    messageTimer = startTimer(() => setMessage(ctx), 1000);
  };

  const stop = (ctx: ExtensionContext, showSummary: boolean, clearSummary = false): void => {
    const elapsedMs = startedAt === null ? null : now() - startedAt;
    clearTimer();
    startedAt = null;
    if (ctx.mode !== "tui") return;

    ctx.ui.setWorkingMessage();
    if (clearSummary) ctx.ui.setWidget(SUMMARY_WIDGET_KEY, undefined);
    else if (showSummary && elapsedMs !== null) setWorkedSummary(ctx, elapsedMs);
  };

  return function workingTimerExtension(pi: ExtensionAPI): void {
    pi.on("agent_start", (_event, ctx) => start(ctx));
    pi.on("agent_settled", (_event, ctx) => stop(ctx, true));
    pi.on("session_shutdown", (_event, ctx) => stop(ctx, false, true));
  };
}

export default createWorkingTimerExtension();
