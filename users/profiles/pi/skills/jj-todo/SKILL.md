---
name: jj-todo
description: "Runs the structured JJ TODO-commit workflow. MUST be used before multi-step features, larger fixes, refactors, task DAGs, or any implementation likely to need more than one revision. Requires the jj-core skill."
metadata:
  keywords: ["jj", "todo", "task", "planning", "commits", "workflow"]
  related: [jj-core, conventional-commits]
  version_target: "0.43.x"
---

# JJ TODO Workflow

Represent work as empty JJ revisions whose descriptions are executable specifications. Fill each revision only when its dependencies are complete. Read and follow `jj-core` before using JJ directly.

Use the `jj_todo` tool for routine task mechanics. Planning quality, dependency judgment, implementation, and completion decisions remain the agent's responsibility.

## Status Flags

These are the only valid task prefixes:

| Flag | Meaning |
| --- | --- |
| `[task:draft]` | Placeholder; specification is incomplete |
| `[task:todo]` | Fully specified, empty, and ready when dependencies permit |
| `[task:wip]` | Currently being implemented |
| `[task:blocked]` | Cannot proceed because of an external dependency |
| `[task:standby]` | Paused pending a decision or because usefulness is uncertain |
| `[task:untested]` | Implemented but not sufficiently validated |
| `[task:review]` | Requires review or a design decision |
| `[task:done]` | Fully implemented and validated |

Use `draft` only while planning. Before work begins, turn every actionable task into a self-contained `todo`. Do not use Conventional Commit headers for these revisions; the `[task:*]` prefix is the workflow contract.

## Write Executable Task Specifications

A ready task description should contain:

```markdown
Short title

## Context
Why this task exists and what problem it solves.

## Requirements
- Concrete behavior or change
- Constraints and safety boundaries

## Implementation notes
Stable pointers to source files, APIs, or decisions when useful.

## Acceptance criteria
- Specific, testable completion condition
- Required validation
```

Keep each task small enough for one focused revision. Prefer stable section, symbol, or file references over line numbers. A worker should not need to make an unstated product or architecture decision.

## Primary Tool Workflow

### 1. Inspect Existing State

Start with `jj_todo` `action: "check"` and, when tasks already exist, `action: "list"`. Resolve conflicts, suspicious multiple-WIP state, or incomplete ancestor tasks before creating or starting more work.

### 2. Create the Task Chain or DAG

For each task:

1. Call `action: "create"` with the intended single `parent`, title, body, and `todo` or `draft` flag. Mutations default to `dryRun: true`.
2. Review the exact resolved parent, command, description, and returned `previewToken`.
3. Apply with the same inputs, `dryRun: false`, and that one-use `previewToken`.
4. Use the returned change ID as the parent of the next sequential task. Use a shared parent only for genuinely independent tasks.

Creation must not move the current working copy. The tool uses `jj new --no-edit`; retain that property in any fallback workflow.

### 3. Start One Ready Task

1. Use `action: "next"` on the current task or intended parent to discover candidate children and reported blockers.
2. Confirm the chosen candidate is reported `ready`; the tool requires it to be `todo` with every task-flagged ancestor `done`.
3. Run `jj edit <task-id>` to enter the selected revision.
4. Call `action: "update"`, `flag: "wip"`; review the default dry-run result and returned `previewToken`.
5. Apply with the same inputs, `dryRun: false`, and that token after confirming the working copy is the intended task.

Only one task may be WIP in a workspace.

### 4. Implement Against the Specification

Read the full task description before editing. Keep changes inside the task's scope, preserve unrelated work, and run the narrowest meaningful validation as implementation proceeds.

If implementation must differ from the specification, record a `## Post-Implementation notes` section explaining the deviation and why it was necessary.

### 5. Validate and Complete

Before marking a task `done`:

- Every requirement is implemented.
- Every acceptance criterion passes.
- Relevant tests, checks, or builds pass.
- No known issue remains and no workaround is being deferred.
- The revision contains the intended files and no unrelated changes.

Then:

1. Run `action: "next"` to review the current specification. Children remain blocked while the current task is not `done`.
2. Preview `action: "update"`, `flag: "done"` and retain its `previewToken`.
3. Apply with the same inputs, `dryRun: false`, and that token only when all completion conditions hold.
4. Run `action: "next"` again; if continuing, `jj edit` exactly one now-ready child and preview/apply its transition to `wip`.

Use `untested`, `review`, `blocked`, or `standby` instead of `done` whenever their conditions apply.

## Tool Actions

| Action | Use |
| --- | --- |
| `list` | List flagged task revisions, optionally by flag |
| `next` | Review the current task; only `todo` children whose task ancestors are all `done` are ready |
| `create` | Create a `todo` or `draft` revision without moving `@` |
| `update` | Change one task flag while preserving its description |
| `check` | Count task states and detect conflicts or suspicious WIP state |

`create` and `update` default to `dryRun: true`. Applying requires `dryRun: false` plus the matching one-use `previewToken`; changed repository state invalidates the token. Previews default to a fresh snapshot so their exact revision and operation identity are current. The tool does not replace `jj edit`, full graph inspection, rebases, splits, or merge construction.

## Dependency and Concurrency Rules

- Task ancestors are dependencies, not merely history.
- Never start a task while any task ancestor is not `done`; treat unexpected readiness output as a tool defect and stop.
- Implement tasks sequentially in a shared workspace.
- Do not run multiple agents against the same JJ workspace; they compete for `@` and can place changes in the wrong revision.
- A background subagent may work on one task only if the parent stops mutating that workspace until it settles.
- Parallel agents require separate JJ workspaces and explicit user approval; see [parallel agents](references/parallel-agents.md).

## Stop and Report

Stop rather than improvising when:

- Changes were made in the wrong revision.
- An earlier task needs amendment.
- Dependencies or requirements are unclear.
- The requested recovery needs a JJ operation not covered by the planned workflow.
- Unexpected conflicts or unrelated modifications appear.

Explain the state and wait for direction. Do not silently rebase, restore, squash, abandon, or rewrite other task revisions.

## CLI Fallback

When `jj_todo` is unavailable, use the Nushell helper scripts documented in [CLI workflow](references/cli-workflow.md). Invoke scripts by absolute path; do not assume they are on `PATH`. The helpers remain secondary to the Pi tool.

## References

- [CLI workflow](references/cli-workflow.md) — helper scripts, linear transitions, and DAG construction
- [Parallel agents](references/parallel-agents.md) — experimental workspace-isolated subagents, explicit opt-in only
- `jj-core` — JJ graph inspection, syntax, recovery, and Git interop
