# Parallel Agents with JJ Workspaces

Target: `jj 0.45.x` and Edxeth's `pi-subagents` extension.

> **Pi only.** Each Edxeth agent definition must set its own workspace `cwd`; the `subagent` tool cannot override it. Other agents' Git worktree isolation is not a substitute for JJ workspaces.

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

```nu
jj workspace add /absolute/path/workspace-feature-a --name feature-a
jj workspace add /absolute/path/workspace-feature-b --name feature-b
jj workspace add /absolute/path/workspace-feature-c --name feature-c
jj workspace list
```

`jj workspace list` prints each workspace root by default (0.44+). Record each absolute workspace path, workspace name, and task change ID. In each workspace, run `jj edit <task-id>` before starting its worker.

Before spawning, review each workspace's project instructions. Edxeth's background
children use `--no-approve`; do not bypass this with `flags`. Trust-gated project
settings and extensions may be omitted. Stop if the task depends on resources the
child cannot load.

## 3. Define and Launch One Worker per Workspace

Create a uniquely named agent file in the parent's `.pi/agents/` directory for
each worker. Copy the configured global `worker.md` definition so its model
allowlist, instructions, and lifecycle settings are preserved; change its
`name` and add an absolute `cwd`:

```yaml
name: feature-a-worker
cwd: /absolute/path/workspace-feature-a
```

Never overwrite the Home Manager-managed global definition. Do not add these
temporary routing files to an implementation task. If making them would contaminate
the coordinating revision, use sequential execution instead.

Launch the named definitions with `subagent`. For multiple workers, use its
`children` array. Every child needs a machine `name` (lower-kebab, 2–4 words),
a human `title`, an `agent` definition name, and a self-contained `task`:

```json
{
  "children": [
    {
      "name": "feature-a-worker",
      "title": "Implement feature A task",
      "agent": "feature-a-worker",
      "task": "Implement JJ task <change-id>. Read its full description, confirm this workspace edits that revision, mark it wip, satisfy every acceptance criterion, validate, and report changed files and checks. Do not publish or launch more agents. Use caller_ping if blocked."
    },
    {
      "name": "feature-b-worker",
      "title": "Implement feature B task",
      "agent": "feature-b-worker",
      "task": "Implement JJ task <other-change-id> in your configured workspace, following the same task-state and validation protocol. Do not publish or launch more agents. Use caller_ping if blocked."
    }
  ]
}
```

Add one entry per approved independent task. Do not pass Nico's `cwd`, `action`,
or `worktree` arguments: Edxeth does not expose them. Do not enable Edxeth's
`llm-as-a-verifier` mode here; it manages Git worktrees and applies staged changes
outside the JJ task workflow.

Keep the worker count small and justified. Never mutate a worker's workspace
while it is running.

## 4. Monitor Without Competing

Record each returned run ID and session-file path. Completion arrives through the
tool result or a parent notification, depending on launch mode. Do not use Nico's
`bg_wait` or `subagent({ action: "status" })` API.

Use `subagent_kill({ id })` to stop a worker and
`subagent_resume({ sessionFile, task })` to continue a saved child. A child's
`caller_ping` ends its process; answer by resuming its session, not by assuming
it is still waiting in memory. In the terminal, `/subagents` shows the fleet.

After launching, continue only with work that cannot affect worker workspaces or
shared task history.

From the main workspace, use read-only inspection:

```nu
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

```nu
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
- [Edxeth documentation](https://github.com/edxeth/pi-subagents#agent-definitions) for agent files and lifecycle controls
