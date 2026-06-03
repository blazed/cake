/**
 * Working timer extension for Pi.
 *
 * Adds elapsed time to the default streaming loader message and shows an
 * animated working indicator in the terminal title while preserving whatever
 * working indicator/spinner Pi or another extension already selected.
 */

import type { ExtensionAPI, ExtensionContext, Theme } from "@earendil-works/pi-coding-agent";
import type { Component, TUI } from "@earendil-works/pi-tui";
import path from "node:path";

let startedAt: number | null = null;
let messageTimer: ReturnType<typeof setInterval> | null = null;
let titleTimer: ReturnType<typeof setInterval> | null = null;
let titleFrameIndex = 0;

const TITLE_FRAMES = ["⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"];
const SUMMARY_WIDGET_KEY = "working-timer-summary";

function clearTimers() {
  if (messageTimer !== null) {
    clearInterval(messageTimer);
    messageTimer = null;
  }

  if (titleTimer !== null) {
    clearInterval(titleTimer);
    titleTimer = null;
  }

  titleFrameIndex = 0;
}


function formatElapsed(elapsedMs: number): string {
  const totalSeconds = Math.max(0, Math.floor(elapsedMs / 1000));
  const seconds = totalSeconds % 60;
  const totalMinutes = Math.floor(totalSeconds / 60);
  const minutes = totalMinutes % 60;
  const hours = Math.floor(totalMinutes / 60);

  if (hours > 0) return `${hours}h ${minutes}m ${seconds}s`;
  if (totalMinutes > 0) return `${totalMinutes}m ${seconds}s`;
  return `${seconds}s`;
}

function getCwdTitlePart(): string {
  return path.basename(process.cwd());
}

function getBaseTitle(pi: ExtensionAPI): string {
  const cwd = getCwdTitlePart();
  const session = pi.getSessionName();
  return session ? `π - ${session} - ${cwd}` : `π - ${cwd}`;
}

function setWorkingTitle(ctx: ExtensionContext) {
  if (!ctx.hasUI || startedAt === null) return;
  const frame = TITLE_FRAMES[titleFrameIndex % TITLE_FRAMES.length];
  ctx.ui.setTitle(`${frame} - ${getCwdTitlePart()}`);
  titleFrameIndex++;
}

function setMessage(ctx: ExtensionContext) {
  if (!ctx.hasUI || startedAt === null) return;
  ctx.ui.setWorkingMessage(`Working... (${formatElapsed(Date.now() - startedAt)})`);
}

function setWorkedSummary(ctx: ExtensionContext, elapsedMs: number) {
  const label = `Worked for ${formatElapsed(elapsedMs)}`;
  ctx.ui.setWidget(SUMMARY_WIDGET_KEY, (_tui: TUI, theme: Theme): Component => ({
    render() {
      return [theme.fg("muted", label)];
    },
    invalidate() {},
  }));
}

function start(ctx: ExtensionContext) {
  clearTimers();
  startedAt = null;

  if (!ctx.hasUI) return;

  ctx.ui.setWidget(SUMMARY_WIDGET_KEY, undefined);

  startedAt = Date.now();
  setMessage(ctx);
  setWorkingTitle(ctx);
  messageTimer = setInterval(() => setMessage(ctx), 1000);
  titleTimer = setInterval(() => setWorkingTitle(ctx), 80);
}

function stop(ctx: ExtensionContext | undefined, pi: ExtensionAPI, showSummary = false) {
  const elapsedMs = startedAt === null ? null : Date.now() - startedAt;
  clearTimers();
  startedAt = null;

  if (!ctx?.hasUI) return;

  ctx.ui.setWorkingMessage();
  ctx.ui.setTitle(getBaseTitle(pi));

  if (showSummary && elapsedMs !== null) setWorkedSummary(ctx, elapsedMs);
}

export default function (pi: ExtensionAPI) {
  pi.on("agent_start", (_event, ctx) => start(ctx));
  pi.on("agent_end", (_event, ctx) => stop(ctx, pi, true));
  pi.on("session_shutdown", (_event, ctx) => stop(ctx, pi));
}
