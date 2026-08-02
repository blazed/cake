/**
 * Working timer extension for Pi.
 *
 * Adds elapsed time to the TUI working message and animates a spinner in the
 * terminal title while the agent is working.
 */

import { basename } from "node:path";
import type { ExtensionAPI, ExtensionContext, Theme } from "@earendil-works/pi-coding-agent";
import { truncateToWidth, type Component, type TUI } from "@earendil-works/pi-tui";

const SUMMARY_WIDGET_KEY = "working-timer-summary";
const TITLE_FRAMES = ["⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"];
const TITLE_INTERVAL_MS = 80;

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

function getBaseTitle(pi: Pick<ExtensionAPI, "getSessionName">): string {
  const cwd = basename(process.cwd());
  const session = pi.getSessionName();
  return session ? `π - ${session} - ${cwd}` : `π - ${cwd}`;
}

export function createWorkingTimerExtension(dependencies: WorkingTimerDependencies = {}) {
  const now = dependencies.now ?? Date.now;
  const startTimer = dependencies.setInterval ?? globalThis.setInterval;
  const stopTimer = dependencies.clearInterval ?? globalThis.clearInterval;
  let startedAt: number | null = null;
  let messageTimer: ReturnType<typeof setInterval> | null = null;
  let titleTimer: ReturnType<typeof setInterval> | null = null;
  let titleFrame = 0;

  const clearTimer = (): void => {
    if (messageTimer !== null) {
      stopTimer(messageTimer);
      messageTimer = null;
    }
  };

  const clearTitleTimer = (): void => {
    if (titleTimer !== null) {
      stopTimer(titleTimer);
      titleTimer = null;
    }
  };

  const setMessage = (ctx: ExtensionContext): void => {
    if (ctx.mode !== "tui" || startedAt === null) return;
    ctx.ui.setWorkingMessage(`Working... (${formatElapsed(now() - startedAt)})`);
  };

  const setTitle = (pi: ExtensionAPI, ctx: ExtensionContext): void => {
    if (ctx.mode !== "tui" || startedAt === null) return;
    const frame = TITLE_FRAMES[titleFrame % TITLE_FRAMES.length] ?? TITLE_FRAMES[0];
    ctx.ui.setTitle(`${frame} ${getBaseTitle(pi)}`);
    titleFrame++;
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

  const start = (pi: ExtensionAPI, ctx: ExtensionContext): void => {
    if (ctx.mode !== "tui") return;
    if (startedAt !== null) {
      setMessage(ctx);
      return;
    }

    ctx.ui.setWidget(SUMMARY_WIDGET_KEY, undefined);
    startedAt = now();
    titleFrame = 0;
    setMessage(ctx);
    setTitle(pi, ctx);
    messageTimer = startTimer(() => setMessage(ctx), 1000);
    titleTimer = startTimer(() => setTitle(pi, ctx), TITLE_INTERVAL_MS);
  };

  const stop = (pi: ExtensionAPI, ctx: ExtensionContext, showSummary: boolean, clearSummary = false): void => {
    const elapsedMs = startedAt === null ? null : now() - startedAt;
    clearTimer();
    clearTitleTimer();
    titleFrame = 0;
    startedAt = null;
    if (ctx.mode !== "tui") return;

    ctx.ui.setWorkingMessage();
    ctx.ui.setTitle(getBaseTitle(pi));
    if (clearSummary) ctx.ui.setWidget(SUMMARY_WIDGET_KEY, undefined);
    else if (showSummary && elapsedMs !== null) setWorkedSummary(ctx, elapsedMs);
  };

  return function workingTimerExtension(pi: ExtensionAPI): void {
    pi.on("agent_start", (_event, ctx) => start(pi, ctx));
    pi.on("agent_settled", (_event, ctx) => stop(pi, ctx, true));
    pi.on("session_shutdown", (_event, ctx) => stop(pi, ctx, false, true));
  };
}

export default createWorkingTimerExtension();
