/**
 * Opt-in, low-overhead profiler for diagnosing UI freezes during workflow runs.
 *
 * Enable with `PI_WF_PROFILE=1 pi` (tune the slow threshold with
 * `PI_WF_PROFILE_SLOW_MS`, default 20). When off, every export here is a no-op
 * with effectively zero cost, so it is safe to leave the call sites in place.
 *
 * It does two things:
 *  1. An event-loop STALL watcher (perf_hooks): a timer that should fire every
 *     250ms; when it fires late, the loop was blocked — we log the drift and the
 *     label of the section that was running, which pinpoints the culprit.
 *  2. `profile(label, fn)`: times a sync or async section and logs it when it
 *     exceeds the slow threshold.
 *
 * Output is appended (async, never blocking) to `.pi/workflows/profile.log`.
 * For a full flame chart instead, see PROFILING.md (node --cpu-prof).
 */

import { appendFile } from "node:fs/promises";
import { join } from "node:path";
import { monitorEventLoopDelay, performance } from "node:perf_hooks";

const RAW = process.env.PI_WF_PROFILE;
const ENABLED = !!RAW && RAW !== "0" && RAW !== "false";
const SLOW_MS = Number(process.env.PI_WF_PROFILE_SLOW_MS ?? 20);

let logPath: string | null = null;
let writeChain: Promise<void> = Promise.resolve();
let current: string | undefined; // label of the section currently executing

function write(line: string): void {
  if (!ENABLED || !logPath) return;
  const ts = new Date().toISOString();
  writeChain = writeChain.then(() => appendFile(logPath as string, `[${ts}] ${line}\n`).catch(() => {}));
}

/** Manual log line into the profile file. */
export function profileLog(line: string): void {
  write(line);
}

/** Set up the stall watcher and log destination. Idempotent; no-op when disabled. */
export function initProfiler(cwd: string): void {
  if (!ENABLED || logPath) return;
  logPath = join(cwd, ".pi", "workflows", "profile.log");

  const hist = monitorEventLoopDelay({ resolution: 10 });
  hist.enable();

  const INTERVAL = 250;
  let last = performance.now();
  const timer = setInterval(() => {
    const now = performance.now();
    const drift = now - last - INTERVAL;
    last = now;
    if (drift > SLOW_MS) {
      write(`event-loop STALL ~${Math.round(drift)}ms during: ${current ?? "(idle/external)"}`);
    }
  }, INTERVAL);
  if (typeof (timer as { unref?: () => void }).unref === "function") {
    (timer as { unref: () => void }).unref();
  }
  write(`profiler enabled — slow>${SLOW_MS}ms, pid=${process.pid}, cwd=${cwd}`);
}

/**
 * Time a section. Returns whatever `fn` returns (awaiting thenables). Logs when
 * the section exceeds SLOW_MS. When disabled, calls `fn` directly with no cost.
 */
export function profile<T>(label: string, fn: () => T): T {
  if (!ENABLED) return fn();
  const start = performance.now();
  const prev = current;
  current = label;
  const done = () => {
    current = prev;
    const ms = performance.now() - start;
    if (ms > SLOW_MS) write(`${label} ${ms.toFixed(1)}ms`);
  };
  try {
    const out = fn();
    if (out && typeof (out as { then?: unknown }).then === "function") {
      return (out as unknown as Promise<unknown>).then(
        (v) => {
          done();
          return v;
        },
        (e) => {
          done();
          throw e;
        },
      ) as unknown as T;
    }
    done();
    return out;
  } catch (e) {
    current = prev;
    write(`${label} THREW after ${(performance.now() - start).toFixed(1)}ms`);
    throw e;
  }
}
