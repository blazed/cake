# JJ TODO CLI Fallback

Target: `jj 0.43.x` with Nushell helper scripts from `../scripts/`.

Use this reference only when the `jj_todo` Pi tool is unavailable or when a DAG operation is not supported by the tool. Planning, dependency, validation, and completion rules remain defined by the main skill.

## Resolve Script Paths

Scripts are not guaranteed to be on `PATH`. Resolve them relative to the skill directory and invoke them by absolute path.

| Script | Purpose |
| --- | --- |
| `jj-todo-create [--draft] <PARENT> <TITLE> [BODY]` | Create one task without moving `@` |
| `jj-parallel-todos [--draft] <PARENT> <TITLE>...` | Create sibling tasks and print their change IDs |
| `jj-merge-todo [--draft] [--desc BODY] <TITLE> <PARENT1> <PARENT2> [PARENT...]` | Create a multi-parent integration task |
| `jj-todo-next [--mark-as FLAG] [NEXT]` | Review the current task and optionally transition |
| `jj-flag-update <REV> <FLAG>` | Update one task prefix |
| `jj-find-flagged [FLAG]` | List task revisions |

The canonical flag list is also recorded in `../scripts/_flags.nu`. `jj-show-desc` is provided by the `jj-core` skill.

## Create a Linear Chain

```bash
/path/to/scripts/jj-todo-create @ "Add validation" "## Context
...

## Requirements
- ...

## Acceptance criteria
- ..."
# prints first change ID

/path/to/scripts/jj-todo-create <first-id> "Add validation tests" "<complete body>"
```

Every creation uses `jj new --no-edit`; verify that the working copy did not move. Use the returned change ID as the next task's parent.

Use `--draft` only for an intentionally incomplete specification. Update it to `todo` before a worker starts.

## Start and Update a Task

```bash
jj edit <task-id>
/path/to/scripts/jj-show-desc @
/path/to/scripts/jj-flag-update @ wip
```

Before editing, inspect the task's parents and confirm no ancestor has an incomplete task flag. After switching, verify `@` is the intended change before updating its status.

List state with:

```bash
/path/to/scripts/jj-find-flagged
/path/to/scripts/jj-find-flagged wip
/path/to/scripts/jj-find-flagged todo
```

## Review and Transition

Without arguments, `jj-todo-next` prints the current specification and candidate child classifications:

```bash
/path/to/scripts/jj-todo-next
```

These classifications are advisory. Before transitioning, independently confirm the chosen revision is a child, is `todo`, and has only `done` task parents and ancestors.

Prefer an explicit, inspectable transition:

```bash
/path/to/scripts/jj-flag-update @ done
jj edit <verified-next-task-id>
/path/to/scripts/jj-flag-update @ wip
```

The script's combined `--mark-as` mode updates the current flag before attempting `jj edit`; it is not atomic. Avoid it unless the target and dependency state were already verified and a partial transition can be recovered safely.

If work is incomplete, use the accurate non-done flag instead:

```bash
/path/to/scripts/jj-flag-update @ untested
/path/to/scripts/jj-flag-update @ review
/path/to/scripts/jj-flag-update @ blocked
/path/to/scripts/jj-flag-update @ standby
```

## Create a Task DAG

Create siblings from one completed parent:

```bash
/path/to/scripts/jj-parallel-todos --draft <parent-id> \
  "Feature A" \
  "Feature B" \
  "Feature C"
```

The helper accepts titles rather than full specifications, so create these siblings as `draft`. Fill each description and update it to `todo` before assigning a worker.

Join completed branches with an integration task:

```bash
/path/to/scripts/jj-merge-todo --draft \
  --desc "Integrate A, B, and C; resolve conflicts and run the full suite." \
  "Integrate features" \
  <feature-a-id> <feature-b-id> <feature-c-id>
```

Complete the integration specification and change it to `todo` before work begins. A multi-parent task depends on every parent; do not begin it until every task parent is `done`.

## Manual Inspection

```bash
jj log -r 'description(substring:"[task:")'
jj log -r 'ancestors(<task-id>, 2)'
jj log -r 'descendants(<task-id>, 2)'
```

Quote revsets. Use the `jj-core` skill for graph syntax, recovery, and any mutation beyond this fallback.

## Completion Checklist

Before setting `done`:

- Re-read the full task description.
- Inspect changed files and diff.
- Run required tests/checks/builds.
- Confirm no known defect, unrelated change, or deferred workaround remains.
- Add `## Post-Implementation notes` when implementation deviated from the specification.

Stop and report wrong-revision work, unexpected conflicts, unclear dependencies, or any need for unplanned history recovery.
