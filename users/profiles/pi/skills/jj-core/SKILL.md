---
name: jj-core
description: Expert guidance for using JJ (Jujutsu) version control system. MUST be used before any `jj` or `git` command or version-control operation in JJ-backed repositories, including status/log/diff/fetch/push/bookmark/branch/history inspection. Covers JJ operations, revsets, templates, evolog, recovery, `jj fix`, and Git interop boundaries.
metadata:
  keywords: ["jj", "jujutsu", "git", "revsets", "bookmarks", "history", "fix", "formatting"]
  related: [jj-todo, conventional-commits]
  version_target: "0.42.x"
---

# JJ (Jujutsu) Version Control Helper

Git-compatible VCS with a different data model: no staging area; the working copy is an editable commit (`@`) that is normally auto-snapshotted before JJ commands. Untracked files can still exist.

> ⚠️ **Avoid `git` mutations in a JJ repo** — they bypass JJ's operation log and can confuse colocated state. Prefer `jj` for mutating operations. Read-only Git commands like `git log`, `git diff`, `git show`, `git blame`, and `git grep` are fine.

Tested against `jj 0.42.0`. Prefer current canonical command names in examples;
short aliases are often configured by default but can be disabled or confusing in
`jj help` output.

## Core Principles

- **Change IDs** (stable identity of a change) vs **Commit IDs** (content-based hashes that change on edit)
- **Operation log**: repository history changes are recorded and can be undone (`jj undo`) or restored (`jj op restore <op-id>`)
- **No staging area**: the working copy is a commit (`@`) and is normally auto-snapshotted before commands
- **Conflicts don't block**: conflicts can exist in commits and be resolved later
- **Commits are lightweight**: edit, split, squash, rebase, and abandon freely
- **Colocated by default**: Git-backed repos typically have both `.jj` and `.git` (since v0.34)
- **Three DSLs**:
  - _revsets_: select revisions/commits (`@`, `@-`, `mine()`, `description(...)`)
  - _filesets_: select files (`src`, `glob:"**/*.ts"`, `~Cargo.lock`)
  - _templates_: select output fields (`change_id.shortest(8)`, `description.first_line()`)

## Essential Commands

```bash
jj status                             # Working-copy status
jj log -r <revset> [-p]               # View history (--patch/-p: include diffs, --count: just count)
jj log -r <revset> -G                 # -G is short for --no-graph
jj show <rev>                         # Show revision details (description + diff)
jj evolog -r <rev> [-p]               # View a revision's evolution

jj new [-A] <base>                    # Create revision and edit it (-A: insert after <base>)
jj new --no-edit <base>               # Create without switching @
jj edit <rev>                         # Switch to editing revision
jj describe <rev> -m "text"           # Set description (canonical name; default alias: desc)
jj describe <rev> --stdin             # Set description from stdin, useful in scripts
jj metaedit <rev> -m "text"           # Modify metadata (author, timestamps, description)

jj diff                               # Changes in @
jj diff -r <revset>                   # Changes in revset (must be contiguous)
jj diff -f <rev1> -t <rev2>           # Differences between two states
jj file show -r <rev> <fileset>       # Show file contents at revision (without switching)
jj file show -r <rev> **/*.md -T '"=== " ++ path ++ " ===\n"'  # Multiple files with path headers
jj restore <fileset>                  # Discard changes to files in @
jj restore --from <rev> <fileset>     # Restore files from another revision

jj split -r <rev> <paths> -m "text"   # Split selected paths into another revision
jj absorb                             # Auto-squash changes into ancestor commits
jj fix [filesets]                    # Run configured fix tools (default source: revsets.fix or reachable(@, mutable()))
jj fix -s <revset> [filesets]        # Limit source revisions and paths/filesets to fix
jj rebase -s <src> -o <dest>          # Rebase source and descendants onto dest
jj rebase -r <rev> -o <dest>          # Rebase only selected revision(s)

jj file annotate <path>               # Blame: who changed each line
jj bisect run -- <cmd>                # Binary search for bug-introducing commit
```

## Additional Commands

```bash
jj undo                               # Undo last operation (repeat to go further back)
jj redo                               # Redo undone operation
jj sign -r <rev>                      # Cryptographically sign commit
jj unsign -r <rev>                    # Remove signature
jj revert -r <rev> -o <dest>          # Create commit that reverts changes
jj bookmark set <name> -r <rev>       # Create/update bookmark (Git branch analogue)
jj bookmark move <name> --to <rev>    # Move existing bookmark
jj bookmark delete <name>             # Delete bookmark and propagate on next push
jj git fetch                          # Fetch from Git remote(s)
jj git push --bookmark <name>         # Push a specific bookmark
jj git push --change <rev>            # Push change under generated bookmark name
jj tag set <name> -r <rev>            # Create/update local tag
jj tag delete <name>                  # Delete local tag
jj git colocation enable              # Convert to colocated repo
jj git colocation disable             # Convert to non-colocated
```

## Formatting/Fixing with `jj fix`

Use `jj fix` when configured formatters or content transformers should be applied
through JJ history rather than directly editing the working tree.

```bash
jj fix                         # Fix changed files in revsets.fix, else reachable(@, mutable())
jj fix -s @                    # Fix @ and its descendants
jj fix 'glob:**/*.nix'         # Limit to matching paths/filesets
jj fix --include-unchanged-files <fileset>  # Also process unchanged matching files
jj fix --all-lines             # Ignore line-range config and format whole modified files
```

By default, `jj fix` rewrites files changed in the source revisions and updates
descendants for the same paths so fixes are not lost. Path arguments are JJ
filesets. Review the operation with `jj op show -p`; recover with `jj undo` (or
`jj op restore <op>` from `jj op log`).

Configure tools in JJ config under `fix.tools.<name>` with a `command` array and
`patterns` filesets. Optional keys include `enabled`, `line-range-arg`, and
`run-tool-if-zero-line-ranges`. Tool commands read stdin and write fixed content
to stdout; use `$path` for the repo-relative file path and `$root` for the
workspace root. See [command syntax](references/command-syntax.md#jj-fix-config-patterns) for expanded examples.

## Quick Revset Reference

```bash
@, @-, @--                            # Working copy, parent(s), grandparent(s)
::@                                   # Ancestors of @
@::                                   # Descendants of @
@+                                    # Children of @
mine()                                # Your changes
conflicts()                           # Revisions with conflicts
visible()                             # Visible revisions (built-in alias)
hidden()                              # Hidden revisions (built-in alias)
description(substring-i:"text")       # Match description (partial, case-insensitive)
subject(substring:"text")             # Match first line only
signed()                              # Cryptographically signed commits
A | B, A & B, A ~ B                   # Union, intersection, difference
change_id(prefix)                     # Explicit change ID prefix lookup
commit_id(prefix)                     # Explicit commit ID prefix lookup
bookmarks(pattern)                    # Bookmark-name pattern lookup
parents(x, 2)                         # Parents with depth
exactly(x, 3)                         # Assert exactly N revisions
```

For the comprehensive list, run `jj help -k revsets`.

## Common Pitfalls

### 1. Prefer short `-r`; long revset flag names vary

`-r` is the safest spelling in snippets and scripts. Long forms are inconsistent
across commands and even help prose: many commands use `--revision`, some prose
mentions `--revisions`, and several commands accept the revset positionally.

```bash
jj log -r xyz              # ✅ idiomatic
jj show xyz                # ✅ positional; `-r xyz` is also accepted as alias
jj describe xyz -m "msg"   # ✅ canonical command name, positional revision
jj rebase -r xyz -o main   # ✅ avoid relying on long-form spelling
```

### 2. Use canonical `describe`, not `desc`, in scripts

`jj desc` is a default alias for `jj describe`, but `jj help desc` may not resolve
aliases in some environments. Use `jj describe` in durable docs/scripts.

```bash
jj describe @ -m "Update docs"        # ✅
printf '%s\n' "Update docs" | jj describe @ --stdin
```

### 3. Use `--no-edit` for parallel branches

```bash
jj new parent -m "A"; jj new -m "B"                             # ❌ B is child of A!
jj new --no-edit parent -m "A"; jj new --no-edit parent -m "B"  # ✅ Both children of parent
```

### 4. Quote revsets and filesets in shell

```bash
jj log -r 'description(substring:"[task:todo]")'    # ✅
jj diff 'glob:"**/*.ts"'                            # ✅
```

### 5. Use `-o`/`--onto` instead of `-d`/`--destination`

```bash
jj rebase -s xyz -o main   # ✅ Current syntax
jj rebase -s xyz -d main   # ⚠️ Accepted alias; avoid in new scripts
```

The same guidance applies to `jj split` and `jj revert`: use `-o`/`--onto`, not
legacy `-d`/`--destination`.

### 6. Symbol expressions are strict

A bare symbol must resolve unambiguously. In scripts, prefer explicit lookup
functions when a name may collide with bookmarks/tags/IDs.

```bash
jj log -r abc              # ❌ Error if ambiguous
jj log -r 'change_id(abc)' # ✅ Explicit change ID prefix
jj log -r 'commit_id(abc)' # ✅ Explicit commit ID prefix
jj log -r 'bookmarks(abc)' # ✅ Bookmark name pattern
```

### 7. Filesets use prefix-glob paths by default (v0.36+)

```bash
jj diff src                # Matches src recursively / path prefix
jj diff 'glob:"src/*.rs"'  # Shell-style glob in current directory
jj diff 'file:"src/*"'     # Literal cwd-relative file path with special chars
```

### 8. Read-only inspection can use `--ignore-working-copy`

For status/diff during active work, let JJ snapshot normally. For prompt/footer
scripts that only need already-snapshotted state and must avoid side effects,
use `--ignore-working-copy`.

```bash
jj log --ignore-working-copy -r @ -G -T 'change_id.shortest(8) ++ " " ++ description.first_line()'
```

## Scripts

Helper scripts live in `scripts/`. They are Nushell scripts (`#!/usr/bin/env nu`);
add them to PATH or invoke them directly from the skill directory.

| Script                             | Purpose                          |
| ---------------------------------- | -------------------------------- |
| `jj-show-desc [REV]`               | Print full description only      |
| `jj-desc-transform <REV> <CMD...>` | Pipe description through command |
| `jj-batch-desc <SED_FILE> <REV...>`| Batch transform descriptions     |
| `jj-checkpoint [NAME]`             | Record op ID before risky ops    |

## Pi Tool

Use the `jj_context` Pi tool for quick read-only repository orientation: current
change, parent, dirty-file summary, conflicts, nearby bookmarks, and recovery op.
It returns structured JSON/text for:

- `mode: "summary"` (default): version, root, current change, nearest bookmarks,
  changed-file/diffstat/conflict summary, recovery operation ID, and a short log
- `mode: "log"`: compact flat log for a revset
- `mode: "changes"`: status/diffstat/changed-file summary
- `mode: "recovery"`: current operation ID and recent operation log

Prefer `jj_context` over several verbose `bash` calls to `jj status`, `jj log`,
`jj diff --stat`, and `jj op log` when a compact overview is enough. Use the
`jj` CLI via `bash` for precise revset inspection, full diffs, unusual commands,
and all mutating operations. Avoid generic `jj_run` wrappers; JJ's CLI is already
expressive and broad wrappers add risk without much token benefit.

## Recovery

```bash
jj op log              # Find operation before problem
jj op show <op-id>     # Inspect what an operation changed
jj op restore <op-id>  # Restore the WHOLE repository (history included) to that state
jj undo                # Undo most recent operation
jj redo                # Redo an undone operation
```

## References

- The `jj` executable is self-documenting:
  - `jj help -k bookmarks` - JJ bookmarks, how they relate to Git branches and how to push/fetch them
  - `jj help -k revsets` - Revset DSL syntax and patterns
  - `jj help -k filesets` - Filepath selection DSL
  - `jj help -k templates` - Template language and custom output
  - All jj subcommands have detailed `--help` pages
- `references/command-syntax.md` - Command flag details
- `references/batch-operations.md` - Complex batch transformations on revision descriptions
