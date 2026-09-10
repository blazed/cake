# Parallel Agents with JJ Workspaces

Target: `jj 0.45.x` and the `pi-subagents` package's `subagent` tool.

> **Experimental:** use this workflow only after the user explicitly approves parallel execution and the additional workspace cleanup.

## When Parallelism Is Justified

Use isolated workspaces only when:

- At least three tasks are genuinely independent.
- Workers will not modify the same files or generated artifacts.
- The time saved exceeds workspace and review overhead.
- Each task has a complete `[task:todo]` specification.
- The user accepts the conflict and cleanup risks.

Otherwise, keep one workspace and implement tasks sequentially.

## Why Isolation Is Mandatory

Agents sharing a workspace compete for the same working-copy revision (`@`). Even unrelated edits can be snapshotted into the wrong task. A JJ workspace gives each worker its own `@` while sharing repository history.

A workspace prevents working-copy collisions; it does not prevent merge conflicts between tasks that touch overlapping content.

## 1. Plan the DAG First

Create the common foundation, independent task revisions, and any integration task before spawning workers. Use `jj_todo create` for ordinary task revisions. Use the CLI helper fallback when constructing a multi-parent merge task; see [CLI workflow](cli-workflow.md).

Verify that every worker task is `todo`, has only completed task ancestors, and has precise acceptance criteria.

## 2. Create Named Workspaces

Create sibling directories, never subdirectories of the main working tree:

```bash
jj workspace add /absolute/path/workspace-feature-a --name feature-a
jj workspace add /absolute/path/workspace-feature-b --name feature-b
jj workspace add /absolute/path/workspace-feature-c --name feature-c
jj workspace list
```

`jj workspace list` prints each workspace root by default (0.44+). Record each absolute workspace path, workspace name, and task change ID. In each workspace, run `jj edit <task-id>` before starting its worker.

Before spawning, ensure Pi's persisted project-trust store covers every alternate `cwd` or a containing directory. Use Pi's normal interactive `/trust` flow and restart as instructed; do not hand-edit `trust.json`. Without persisted trust, subagents fail closed and omit trust-gated project settings, extensions, and resources. Proceed in that degraded mode only when it is intentional and sufficient for the task.

## 3. Spawn One Worker per Workspace

Launch one async `subagent` call per worker and pass the workspace path as `cwd`. Inspect the installed interface with `subagent({ action: "list" })` when unsure which agents are available.

Each call needs:

- `agent`: the builtin `worker` for a Pi child, or a deliberate Claude Code agent when a Claude child is required
- `cwd` set to the workspace's absolute path
- `task`: a self-contained prompt containing the exact task change ID and specification
- explicit instructions to inspect the current task, update it to `wip`, implement only that task, validate it, and report completion or blockage
- a reminder that the child cannot ask the user or orchestrate more agents

Record each run id as it is returned; it identifies the worker for `bg_wait`, `subagent({ action: "status", id })`, and steering.

Example payload shape:

```json
{
  "agent": "worker",
  "cwd": "/absolute/path/workspace-feature-a",
  "task": "Implement JJ task <change-id>. Read its full description, confirm this workspace edits that revision, mark it wip, satisfy every acceptance criterion, validate, and report changed files and checks. Stop on ambiguity or conflicts."
}
```

Children run async by default and are bounded by pi-subagents concurrency settings; keep the worker count small and justified rather than filling capacity. Do not tell workers to `cd`; `cwd` establishes their process directory. Do not use the package's git-worktree isolation (`worktree: true`) in this repository — JJ workspaces are the isolation mechanism. Do not let the parent or another worker mutate a worker's workspace while it is running.

## 4. Monitor Without Competing

After spawning, continue only with work that cannot affect worker workspaces or shared task history. Workers notify the parent natively when they settle, so do not call `bg_wait` just because they are running. Use `bg_wait` with the worker's run id only when this turn genuinely cannot proceed without the result, and use `subagent({ action: "status" })` to inspect the fleet.

From the main workspace, use read-only inspection:

```bash
jj workspace list
jj log -r 'description(substring:"[task:")'
jj status
```

The `jj_todo list` and `check` actions can summarize shared task state. Treat a child's claim of completion as a report, not proof; inspect its revision and validation output.

## 5. Integrate and Clean Up

After every worker has settled:

1. Verify each task revision contains only its intended changes.
2. Confirm flags and validation; correct status only with the normal dry-run workflow.
3. Inspect the multi-parent integration revision for conflicts.
4. Resolve conflicts in the integration task, not by rewriting completed worker tasks without review.
5. Forget workspaces only after their revisions are safely visible from the main repository.

```bash
jj workspace forget feature-a feature-b feature-c
```

Deleting the workspace directories is a separate filesystem operation. Reconfirm their paths and user intent before removal; never use a broad glob or an unverified `rm -rf`.

## Failure Handling

- **Worker edited the wrong task:** stop that worker and report; do not silently move its changes.
- **Two tasks touched the same file:** expect an integration conflict and review both intents.
- **Worker is blocked:** leave an accurate `blocked`, `standby`, `untested`, or `review` flag and report why.
- **Workspace disappeared:** inspect `jj workspace list` and repository operations before recreating anything.
- **Agent did not reply:** completion is delivered through Pi's native notifications; inspect run status rather than spawning a duplicate worker immediately.

## Safety Rules

- Never run parallel workers in the same workspace.
- Never assign a `draft` task.
- Never let workers publish, push, or perform broad recovery operations.
- Never clean workspaces until workers have settled and revisions are verified.
- Prefer sequential work whenever independence is uncertain.

## References

- `jj help workspace`
- [CLI workflow](cli-workflow.md)
- The `jj-core` skill for graph inspection and recovery
- The installed `pi-subagents` skill (`subagent` controls and lane orchestration)
