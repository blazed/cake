/**
 * Configuration constants for pi-dynamic-workflows.
 */

/** Maximum number of agents allowed per workflow run. */
export const MAX_AGENTS_PER_RUN = 1000;

/** Default timeout for a single agent in milliseconds (5 minutes). */
export const DEFAULT_AGENT_TIMEOUT_MS = 5 * 60 * 1000;

/**
 * Maximum concurrent agents. Subagents run in-process on Pi's single event loop
 * (shared with the interactive TUI), so a high cap makes the UI lag while a wide
 * fan-out streams. 6 keeps real parallelism while staying responsive; the
 * network-bound agents still overlap. Raise it for headless/background runs.
 */
export const MAX_CONCURRENCY = 6;

/** Default token budget if none specified. */
export const DEFAULT_TOKEN_BUDGET = null;

/**
 * Max wall-clock for a workflow script's SYNCHRONOUS evaluation, enforced via a
 * `vm` timeout. This bounds only the script's sync prefix (up to its first
 * `await`) — which is exactly the freeze case: a synchronous infinite loop
 * before any await would otherwise block the TUI event loop. Async
 * orchestration time (awaiting agents) is unbounded by this.
 */
export const WORKFLOW_SYNC_TIMEOUT_MS = 10_000;

/** Directory for persisting workflow run state. */
export const WORKFLOW_RUNS_DIR = ".pi/workflows/runs";

/** Directory for saved workflow commands. */
export const WORKFLOW_SAVED_DIR = ".pi/workflows/saved";

/** User-level saved workflows directory. */
export const USER_WORKFLOW_SAVED_DIR = "~/.pi/workflows/saved";
