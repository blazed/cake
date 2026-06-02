/**
 * Workflow run state persistence for pause/resume support.
 */

import { existsSync, mkdirSync, readdirSync, readFileSync, renameSync, unlinkSync, writeFileSync } from "node:fs";
import { rename, unlink, writeFile } from "node:fs/promises";
import { join } from "node:path";
import { WORKFLOW_RUNS_DIR } from "./config.ts";
import { assertInside, assertSafeName } from "./fs-safety.ts";

/**
 * Hot-path writes (one per agent completion) are coalesced over this window and
 * written asynchronously, so a wide fan-out doesn't block Pi's TUI event loop
 * with synchronous disk I/O. Terminal states use `save()` (sync, durable).
 */
const PERSIST_DEBOUNCE_MS = 250;

export type RunStatus = "pending" | "running" | "paused" | "completed" | "failed" | "aborted";

export interface PersistedAgentState {
  id: number;
  label: string;
  phase?: string;
  prompt: string;
  status: "queued" | "running" | "done" | "error" | "skipped";
  result?: unknown;
  error?: string;
  startedAt?: string;
  endedAt?: string;
  /** The model this agent ran on (provider/id), when known. */
  model?: string;
}

export interface PersistedRunState {
  runId: string;
  workflowName: string;
  script: string;
  args?: unknown;
  status: RunStatus;
  phases: string[];
  currentPhase?: string;
  agents: PersistedAgentState[];
  logs: string[];
  result?: unknown;
  startedAt: string;
  updatedAt: string;
  completedAt?: string;
  durationMs?: number;
  tokenUsage?: {
    input: number;
    output: number;
    total: number;
  };
  /** Cached agent results for resume, keyed by deterministic call index. */
  journal?: Array<{ index: number; hash: string; result: unknown }>;
}

export interface RunPersistence {
  /** Save current run state immediately and synchronously (durable across exit). */
  save(state: PersistedRunState): void;
  /**
   * Coalesced, asynchronous save for the hot path (per-agent progress). Multiple
   * calls within PERSIST_DEBOUNCE_MS collapse into one non-blocking write. Pass
   * the latest full state each time; the most recent wins. A subsequent `save()`
   * supersedes any pending scheduled write for the same run.
   */
  scheduleSave(state: PersistedRunState): void;
  /** Load a persisted run by ID. */
  load(runId: string): PersistedRunState | null;
  /** List all persisted runs. */
  list(): PersistedRunState[];
  /** Delete a persisted run. */
  delete(runId: string): boolean;
  /** Get runs directory path. */
  getRunsDir(): string;
}

export function createRunPersistence(cwd: string): RunPersistence {
  const runsDir = join(cwd, WORKFLOW_RUNS_DIR);

  const ensureDir = () => {
    if (!existsSync(runsDir)) {
      mkdirSync(runsDir, { recursive: true });
    }
  };

  // Validate the ID (generateRunId() output passes) and confirm the path stays
  // under runsDir, so an externally-supplied runId can't escape via `../`.
  const runPath = (runId: string) => assertInside(runsDir, join(runsDir, `${assertSafeName(runId)}.json`));

  // Atomic write: a crash mid-write must never leave a truncated `${runId}.json`
  // (which list() would drop and load() would silently discard). Write a uniquely
  // named temp in the same dir, then rename into place (atomic on POSIX). The temp
  // ends in `.tmp`, so list()'s `.json` filter ignores any orphan. The pid+seq
  // suffix keeps a sync save() and an in-flight async write from sharing a temp.
  let tmpSeq = 0;
  const tmpPath = (path: string) => `${path}.${process.pid}.${tmpSeq++}.tmp`;

  const writeAtomicSync = (path: string, data: string) => {
    const tmp = tmpPath(path);
    try {
      writeFileSync(tmp, data);
      renameSync(tmp, path);
    } catch (err) {
      try {
        if (existsSync(tmp)) unlinkSync(tmp);
      } catch {
        // best-effort temp cleanup
      }
      throw err;
    }
  };

  const writeAtomic = async (path: string, data: string) => {
    const tmp = tmpPath(path);
    try {
      await writeFile(tmp, data);
      await rename(tmp, path);
    } catch {
      await unlink(tmp).catch(() => {});
    }
  };

  // Debounced async-write state for scheduleSave(). One pending state + one timer
  // per run; writes are serialized through a chain so they never interleave.
  const pending = new Map<string, PersistedRunState>();
  const timers = new Map<string, ReturnType<typeof setTimeout>>();
  let writeChain: Promise<void> = Promise.resolve();

  const cancelPending = (runId: string) => {
    const timer = timers.get(runId);
    if (timer) {
      clearTimeout(timer);
      timers.delete(runId);
    }
    pending.delete(runId);
  };

  return {
    save(state: PersistedRunState) {
      // A durable write supersedes any pending debounced write for this run.
      cancelPending(state.runId);
      ensureDir();
      state.updatedAt = new Date().toISOString();
      writeAtomicSync(runPath(state.runId), JSON.stringify(state));
    },

    scheduleSave(state: PersistedRunState) {
      pending.set(state.runId, state);
      if (timers.has(state.runId)) return;
      const timer = setTimeout(() => {
        timers.delete(state.runId);
        const latest = pending.get(state.runId);
        if (!latest) return;
        pending.delete(state.runId);
        ensureDir();
        latest.updatedAt = new Date().toISOString();
        writeChain = writeChain.then(() => writeAtomic(runPath(latest.runId), JSON.stringify(latest)));
      }, PERSIST_DEBOUNCE_MS);
      // Don't keep the process alive just for a pending progress write.
      if (typeof (timer as { unref?: () => void }).unref === "function") {
        (timer as { unref: () => void }).unref();
      }
      timers.set(state.runId, timer);
    },

    load(runId: string): PersistedRunState | null {
      try {
        const path = runPath(runId);
        if (!existsSync(path)) return null;
        return JSON.parse(readFileSync(path, "utf-8")) as PersistedRunState;
      } catch {
        return null;
      }
    },

    list(): PersistedRunState[] {
      ensureDir();
      try {
        const files = readdirSync(runsDir).filter((f) => f.endsWith(".json"));
        const runs: PersistedRunState[] = [];
        for (const file of files) {
          try {
            const state = JSON.parse(readFileSync(join(runsDir, file), "utf-8")) as PersistedRunState;
            runs.push(state);
          } catch {
            // Skip corrupted files
          }
        }
        return runs.sort((a, b) => new Date(b.updatedAt).getTime() - new Date(a.updatedAt).getTime());
      } catch {
        return [];
      }
    },

    delete(runId: string): boolean {
      try {
        const path = runPath(runId);
        if (existsSync(path)) {
          unlinkSync(path);
          return true;
        }
        return false;
      } catch {
        return false;
      }
    },

    getRunsDir(): string {
      return runsDir;
    },
  };
}

/**
 * Generate a unique run ID.
 */
export function generateRunId(): string {
  const timestamp = Date.now().toString(36);
  const random = Math.random().toString(36).slice(2, 8);
  return `${timestamp}-${random}`;
}
