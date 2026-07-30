---
name: jj-core
description: "Guides safe JJ (Jujutsu) version-control work. MUST be used before any jj or git command or history operation in a JJ-backed repository, including status, diff, log, fetch, push, bookmarks, rebases, recovery, and Git interop."
metadata:
  keywords: ["jj", "jujutsu", "git", "revsets", "bookmarks", "history", "fix", "formatting"]
  related: [jj-todo, conventional-commits]
  version_target: "0.43.x"
---

# JJ (Jujutsu) Version Control

JJ has no staging area: the working copy is an editable commit (`@`) that is normally snapshotted before each command. Change IDs remain stable across rewrites; commit IDs change with content.

Tested against `jj 0.43.0`. Prefer canonical command names and short, stable flags in durable instructions.

## Mandatory Boundaries

- Prefer `jj` for all version-control operations in JJ-backed repositories.
- Never use mutating `git` commands in a colocated JJ repository; they bypass JJ's operation model. Read-only Git inspection is acceptable when a tool requires it.
- Do not discard, restore, abandon, rebase, squash, split, or publish changes until the intended revisions and affected files are understood.
- Preserve unrelated user changes. Stop and report unexpected conflicts or repository state instead of guessing.
- Quote revsets and filesets in shell commands.

## Core Model

- `@` is the working-copy commit; `@-` is its parent and `@+` its child set.
- Revisions may be rewritten freely while mutable; descendants are rebased automatically.
- Conflicts can exist in commits and do not block most JJ operations.
- Every repository mutation is recorded in the operation log and can usually be inspected or recovered.
- Revsets select revisions, filesets select paths, and templates format output.

## Inspect Before Acting

Use `jj_context` for compact routine inspection when available:

- `summary`: current change, parent, bookmarks, files, conflicts, and recovery operation
- `changes`: status, diffstat, changed files, and conflicts
- `log`: compact log for a focused revset
- `recovery`: current and recent operation IDs

Let it snapshot the working copy when current state matters. Use the JJ CLI for full diffs, precise graph queries, and all mutations.

```bash
jj status
jj log -r '<revset>'
jj show <rev>
jj evolog -r <rev>
jj diff
jj diff -r <revset>
jj diff -f <from> -t <to>
jj file show -r <rev> <fileset>
```

## Routine Mutations

```bash
jj new <parent>                         # create and edit a child
jj new --no-edit <parent>               # create without moving @
jj edit <rev>                           # switch the working copy
jj describe <rev> -m "message"         # set description
jj describe <rev> --stdin               # read description from stdin
jj bookmark set <name> -r <rev>
jj rebase -r <rev> -o <destination>
```

Use `--no-edit` whenever creating sibling or future task revisions. In scripts, use canonical `describe`, not the optional `desc` alias. Prefer `-r` for revision selection and `-o`/`--onto` over legacy `-d`/`--destination`.

For risky local graph mutations, `--no-integrate-operation` can create an operation without integrating it immediately. It does **not** prevent external side effects such as pushes.

After a mutation, inspect the affected revision or graph before continuing.

## Revsets and Filesets

```bash
::@                                      # ancestors of @
@::                                      # descendants of @
mine()                                   # your revisions
conflicts()                              # revisions with conflicts
description(substring:"text")          # description match
subject(substring:"text")              # first-line match
change_id(prefix)                        # explicit change ID
commit_id(prefix)                        # explicit commit ID
A | B, A & B, A ~ B                     # union, intersection, difference

jj diff src                              # prefix path
jj diff 'glob:"src/*.rs"'              # shell-style glob
jj diff 'file:"src/*"'                 # literal path containing metacharacters
```

A bare symbol must resolve unambiguously. Prefer explicit lookup functions when an ID may collide with a bookmark or tag. Run `jj help -k revsets` or `jj help -k filesets` for the complete grammar.

## Formatting with `jj fix`

Use `jj fix` when configured repository formatters should rewrite files through JJ history. Without `-s`, JJ may use `revsets.fix` or a broad mutable-revision default; always choose the source revset deliberately.

```bash
jj fix -s @
jj fix -s @ 'glob:**/*.nix'
jj fix -s @ --include-unchanged-files <fileset>
jj fix -s @ --all-lines
```

Review rewritten revisions and descendants with `jj op show -p` before continuing. See [command syntax](references/command-syntax.md#jj-fix-config-patterns) for tool configuration.

## Git Interop and Publishing

```bash
jj git fetch
jj git push --bookmark <name>
jj git push --change <rev>
jj bookmark delete <name>
```

Fetch is routine; pushing, deleting remote-tracked bookmarks, signing, and other externally visible operations require an explicit user request or a clearly established release workflow.

## Helper Scripts

Scripts are under `scripts/` and use Nushell:

| Script | Purpose |
| --- | --- |
| `jj-show-desc [REV]` | Print the full description only |
| `jj-desc-transform <REV> <CMD...>` | Transform one description |
| `jj-batch-desc <SED_FILE> <REV...>` | Transform several descriptions |
| `jj-checkpoint [NAME]` | Record an operation ID before risky work |

Invoke them with an absolute path or from the skill directory; do not assume they are on `PATH`.

## Recovery

```bash
jj op log                 # find a known-good operation
jj op show <op-id>        # inspect what an operation changed
jj op restore <op-id>     # restore the whole repository to that operation
jj undo                   # undo the latest operation
jj redo                   # redo an undone operation
```

`jj op restore` changes repository history and working-copy state. Confirm the operation ID and user intent before running it.

## References

- [Command syntax](references/command-syntax.md) — flags, command patterns, revsets, filesets, quoting, and `jj fix` configuration
- [Batch operations](references/batch-operations.md) — safe multi-revision description transformations
- Built-in help: `jj help -k revsets`, `jj help -k filesets`, `jj help -k templates`, and each subcommand's `--help`
