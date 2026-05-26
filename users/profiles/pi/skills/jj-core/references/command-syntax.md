# JJ Command Syntax Reference

Target: `jj 0.41.x`.

## The `-r` Flag

Most commands that select revisions accept `-r`. Prefer `-r` in snippets and
scripts because long-form names and positional aliases vary by command.

```bash
jj log -r <revset>          # ✅ idiomatic
jj log --revision <revset>  # ✅ canonical for log
jj show <revset>            # ✅ positional; -r is accepted as an alias
jj describe <revset> -m msg # ✅ positional; -r is accepted as an alias
jj rebase -r <revset> -o main
jj edit <revset>
```

In 0.41, some help prose mentions `--revisions/-r` while the option table says
`--revision`. Avoid the mismatch by using `-r` unless the long form is important
for readability.

## Canonical Command Names

```bash
jj describe <rev> -m "msg"       # Canonical; default alias: jj desc
jj operation log                 # Canonical; default alias: jj op log
jj bookmark set name -r <rev>    # Canonical; default alias: jj b set ...
```

Use canonical names in scripts/docs. Aliases are handy interactively but can be
missing from `jj help <alias>` or overridden by config.

## Commonly Used Short Flags

```bash
-G                        # Short for --no-graph
-o                        # Short for --onto (prefer over legacy -d)
-f / -t                   # Short for --from / --to (various commands)
-T                        # Template expression
```

## Legacy / Deprecated Forms

```bash
# ⚠️ Legacy-ish             # ✅ Prefer
jj rebase -d main           → jj rebase -o main
jj split -d main            → jj split -o main
jj revert -d main           → jj revert -o main
jj describe --edit          → jj describe --editor
```

By 0.41, `-d` is still accepted as an alias for `-o` on rebase/split/revert.
Prefer `-o`/`--onto` in new scripts and docs.

## Command Patterns

### Reading Revision Info

```bash
# Get description only (for processing)
jj log -r <rev> -n1 --no-graph -T description

# Get detailed info (human-readable)
jj log -r <rev> -n1 --no-graph -T builtin_log_detailed

# Get compact one-liner
jj log -r <rev> -T 'change_id.shortest(4) ++ " " ++ description.first_line()'
```

**Key flags:**

- `-n1`: Limit to 1 revision
- `--no-graph` / `-G`: No ASCII art graph
- `-T <template>`: Output template
- `-r <revset>`: Which revision(s)

### Modifying Descriptions

```bash
# Change description from string
jj describe <rev> -m "New description"

# Change description from stdin (for scripts)
echo "New description" | jj describe <rev> --stdin

# Change description from file
jj describe <rev> --stdin < /path/to/description.txt

# Pipeline pattern
jj log -r <rev> -n1 --no-graph -T description | \
  sed 's/old/new/' | \
  jj describe <rev> --stdin
```

**Key insight:** `--stdin` is essential for scripted description updates.

### Creating Revisions

```bash
# Create and edit immediately (moves @)
jj new <parent> -m "Description"

# Create without editing (@ stays put) - IMPORTANT for parallel branches
jj new --no-edit <parent> -m "Description"

# Create with multiple parents (merge)
jj new --no-edit <parent1> <parent2> -m "Merge point"
```

**Critical distinction:**

- Without `--no-edit`: Your working copy (`@`) moves to the new revision
- With `--no-edit`: New revision is created, but `@` stays where it was

### Operation Safety

```bash
# Inspect old repository state without switching the real repo
jj --at-op=<op-id> status

# Dry-run a mutating jj operation into an unintegrated operation
jj rebase -r <rev> -o <dest> --no-integrate-operation

# Recover whole repository history to a known operation
jj op restore <op-id>
```

`--no-integrate-operation` is useful for local JJ graph mutations, but it does
not prevent side effects outside the repo (for example, a Git push still pushes).

## Revset Syntax

### Basic Revsets

```bash
@                    # Working copy
@-                   # Parent(s) of working copy
@+                   # Children of working copy
<change-id>          # Specific visible revision by change ID prefix
<commit-id>          # Specific revision by commit hash prefix
```

### Operators

```bash
<rev>::<rev>         # Descendants of left that are ancestors of right
<rev>..              # Revisions that are not ancestors of rev
..<rev>              # Ancestors of rev, excluding root
::<rev>              # Ancestors of rev, including root

# Examples
zyxu::@              # All revisions from zyxu to current along ancestry path
roww::               # roww and all descendants
::@                  # All ancestors of @
```

### Functions

```bash
description(glob:"pattern")       # Match description
subject(substring:"text")         # Match first line
change_id(abc)                    # Explicit change ID prefix
commit_id(abc)                    # Explicit commit ID prefix
bookmarks(glob:"feature/*")       # Bookmark names
mine()                            # Your commits
conflicts()                       # Commits with conflicts
```

### Combining

```bash
rev1 | rev2        # Union (OR)
rev1 & rev2        # Intersection (AND)
rev1 ~ rev2        # Difference
mine() & ::@       # Your changes in current ancestry
```

## Fileset Syntax

By default, a plain path is a cwd-relative `prefix-glob:` pattern.

```bash
jj diff src                  # src and descendants
jj diff 'glob:"src/*.rs"'    # shell-style glob in cwd
jj diff 'file:"src/*"'       # literal cwd-relative file path with special char
jj diff '~Cargo.lock'        # exclude file/path pattern
```

## Shell Quoting

Revsets and filesets often need shell quotes because they contain special
characters:

```bash
# ❌ Shell interprets punctuation/globs
jj log -r description(glob:"[todo]*")

# ✅ Single quotes (safest)
jj log -r 'description(glob:"[todo]*")'

# ✅ Double quotes with escaping
jj log -r "description(glob:\"[todo]*\")"
```

**Rule:** When in doubt, use single quotes around revsets/filesets.

## Common Patterns

### Update Multiple Revisions

```bash
# Pattern: Extract → Transform → Apply
for rev in a b c; do
  jj log -r "$rev" -n1 --no-graph -T description > /tmp/desc.txt
  # ... transform /tmp/desc.txt ...
  jj describe "$rev" --stdin < /tmp/desc.txt
done
```

### Find and Update

```bash
# Find all [todo] revisions
jj log -r 'description(glob:"[todo]*")'

# Update specific one
jj log -r xyz -n1 --no-graph -T description | \
  sed 's/\[todo\]/[wip]/' | \
  jj describe xyz --stdin
```

### Create Parallel Branches

```bash
# All branch from same parent
parent=xyz
jj new --no-edit "$parent" -m "[todo] Branch A"
jj new --no-edit "$parent" -m "[todo] Branch B"
jj new --no-edit "$parent" -m "[todo] Branch C"
```

## Debugging

```bash
# Did my command work?
jj log -r <rev> -T 'change_id ++ " " ++ description.first_line()'

# View full description
jj log -r <rev> -n1 --no-graph -T description

# Check revision graph
jj log -r '<parent>::' -T builtin_log_compact
```

## Quick Reference Card

| Task             | Command                                         |
| ---------------- | ----------------------------------------------- |
| View description | `jj log -r <rev> -n1 --no-graph -T description` |
| Set description  | `jj describe <rev> -m "text"`                  |
| Set from stdin   | `jj describe <rev> --stdin`                     |
| Create (edit)    | `jj new <parent> -m "text"`                    |
| Create (no edit) | `jj new --no-edit <parent> -m "text"`          |
| Range query      | `jj log -r '<from>::<to>'`                      |
| Find pattern     | `jj log -r 'description(glob:"pat*")'`         |
