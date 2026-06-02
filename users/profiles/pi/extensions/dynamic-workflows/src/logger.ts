/**
 * Workflow logger with file persistence.
 *
 * All disk I/O is serialized on a single async write chain (mirroring
 * profiler.ts) so log()/warn()/error() never block the TUI event loop —
 * synchronous fs writes here would freeze Pi on every log line.
 */

import { appendFile, mkdir, writeFile } from "node:fs/promises";
import { join } from "node:path";
import { WORKFLOW_RUNS_DIR } from "./config.ts";

export interface WorkflowLogger {
  log(message: string): void;
  error(message: string): void;
  warn(message: string): void;
  getLogs(): string[];
  persist(): string | null;
}

export interface WorkflowLoggerOptions {
  /** Run ID for persistence. */
  runId?: string;
  /** Working directory for file paths. */
  cwd?: string;
  /** Whether to persist logs to disk. */
  persist?: boolean;
  /** Callback for each log entry. */
  onLog?: (message: string) => void;
}

export function createWorkflowLogger(options: WorkflowLoggerOptions = {}): WorkflowLogger {
  const logs: string[] = [];
  const persistLogs = options.persist ?? true;
  const cwd = options.cwd ?? process.cwd();
  const runId = options.runId ?? `run-${Date.now()}`;
  const logFile = persistLogs ? join(cwd, WORKFLOW_RUNS_DIR, `${runId}.log`) : null;

  // Serialized I/O chain: starts with a one-time async mkdir, then every write
  // is appended to the tail. Each step swallows its own error so a single failed
  // write can never reject the chain or block a later one.
  let writeChain: Promise<void> = logFile
    ? mkdir(join(cwd, WORKFLOW_RUNS_DIR), { recursive: true }).then(
        () => {},
        () => {},
      )
    : Promise.resolve();

  const queue = (op: () => Promise<unknown>): void => {
    writeChain = writeChain.then(() => op().then(() => {}, () => {}));
  };

  const write = (level: string, message: string) => {
    const timestamp = new Date().toISOString();
    const entry = `[${timestamp}] [${level}] ${message}`;
    logs.push(entry);
    options.onLog?.(message);
    if (logFile) queue(() => appendFile(logFile, `${entry}\n`));
  };

  const logger: WorkflowLogger = {
    log(message: string) {
      write("INFO", message);
    },
    error(message: string) {
      write("ERROR", message);
    },
    warn(message: string) {
      write("WARN", message);
    },
    getLogs() {
      return [...logs];
    },
    persist() {
      if (!logFile) return null;
      // Snapshot the buffer now (matches the old sync semantics) and queue the
      // full rewrite. The path is deterministic, so we return it synchronously
      // while the write drains on the chain.
      const snapshot = `${logs.join("\n")}\n`;
      queue(() => writeFile(logFile, snapshot));
      return logFile;
    },
  };

  return logger;
}
