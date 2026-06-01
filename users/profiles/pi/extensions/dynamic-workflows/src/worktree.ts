/**
 * Per-agent JJ workspace isolation. When an agent requests `isolation: "worktree"`,
 * it runs in a throwaway `jj workspace` on its own working-copy commit so parallel
 * agents can edit the same files without conflict. Results are NOT auto-merged — the
 * path is surfaced for the caller to inspect. Falls back to a logged no-op when
 * isolation isn't possible.
 *
 * JJ-only by design: this machine uses Jujutsu everywhere, so isolation is built on
 * `jj workspace` rather than `git worktree`. JJ workspaces share the underlying repo
 * (`.jj/repo`) but keep independent working copies, and they live under the project
 * dir (`<repoRoot>/.pi/worktrees/`), so isolation also works inside the jailed-pi
 * sandbox (which only exposes the project cwd read-write).
 */

import { execFile } from "node:child_process";
import { join } from "node:path";
import { promisify } from "node:util";

const exec = promisify(execFile);

// `--ignore-working-copy` keeps these commands from snapshotting (and thereby
// mutating) the user's current `@` while a workflow fans out in the background.
const JJ_GLOBAL = ["--ignore-working-copy"];

export interface Worktree {
  /** True when a real workspace was created; false means "ran in the shared tree". */
  isolated: boolean;
  /** cwd the agent should run in (workspace path when isolated, else the base cwd). */
  cwd: string;
  /** JJ workspace name (kept on `branch` for caller/interface compatibility). */
  branch?: string;
  /** Repo root the workspace was added to (for teardown). */
  repoRoot?: string;
  /** Why isolation was skipped, when isolated === false. */
  reason?: string;
}

function slug(name: string): string {
  return (
    name
      .toLowerCase()
      .replace(/[^a-z0-9]+/g, "-")
      .replace(/^-+|-+$/g, "")
      .slice(0, 32) || "agent"
  );
}

/**
 * Create an isolated JJ workspace under `<repoRoot>/.pi/worktrees/<name>` named
 * `pi-wf-<name>`. The `name` must be deterministic (derived from runId + call index,
 * never wall-clock) so resume keys stay stable. Returns a no-op Worktree on any failure.
 */
export async function createWorktree(baseCwd: string, name: string): Promise<Worktree> {
  const id = slug(name);
  let repoRoot: string;
  try {
    const { stdout } = await exec("jj", [...JJ_GLOBAL, "root"], { cwd: baseCwd });
    repoRoot = stdout.trim();
  } catch {
    return { isolated: false, cwd: baseCwd, reason: "not a jj repository" };
  }

  const path = join(repoRoot, ".pi", "worktrees", id);
  const workspace = `pi-wf-${id}`;
  try {
    await exec("jj", [...JJ_GLOBAL, "workspace", "add", "--name", workspace, path], { cwd: repoRoot });
    return { isolated: true, cwd: path, branch: workspace, repoRoot };
  } catch (error) {
    return { isolated: false, cwd: baseCwd, reason: error instanceof Error ? error.message : String(error) };
  }
}

/** Forget a workspace and remove its directory. Best-effort; safe on a no-op Worktree. */
export async function removeWorktree(wt: Worktree): Promise<void> {
  if (!wt.isolated || !wt.repoRoot) return;
  if (wt.branch) {
    try {
      await exec("jj", [...JJ_GLOBAL, "workspace", "forget", wt.branch], { cwd: wt.repoRoot });
    } catch {
      // already forgotten / locked — fall through
    }
  }
  try {
    await exec("rm", ["-rf", "--", wt.cwd]);
  } catch {
    // directory already gone — best-effort cleanup
  }
}
