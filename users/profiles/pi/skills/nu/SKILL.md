---
name: nu
description: Nushell guidance for writing/debugging Nu scripts and pipelines, manipulating structured data, replacing jq/sed/awk one-liners, parsing command output, working with CSV/JSON/YAML/TOML, and shell automation. Use when the user asks about Nushell/nu or when adding/editing .nu scripts.
metadata:
  tags: ["nushell", "nu", "shell", "structured-data", "jq"]
---

# Nushell (`nu`)

Nushell is a structured shell: pipelines pass typed values (records, lists,
tables) rather than only strings. Prefer it for data shaping, JSON/CSV/TOML/YAML,
repo helper scripts, and shell automation when Nu is available.

Current local version checked while authoring: `nu 0.112.2`.

## Use Nu When

- Writing or debugging `.nu` scripts.
- Parsing structured files: `open data.json`, `open data.csv`, `open flake.lock`.
- Replacing `jq` for JSON transformations.
- Replacing fragile `awk`/`sed`/`grep` pipelines when table/record operations fit.
- Building command-line helpers with typed args/flags.

Use Bash/external tools when exact POSIX shell behavior, process substitution, or
byte-for-byte stream behavior is required.

## Core Mental Model

```nu
open data.csv                         # extension-aware parser -> table
'{"name":"Alice","age":30}' | from json
ls | where size > 10mb | sort-by modified | reverse | first 5
$data | to json | save --force out.json
```

Useful types:

- **record**: `{name: Alice, age: 30}` (jq object)
- **list**: `[1 2 3]` (jq array)
- **table**: list of records with common columns
- **cell path**: `foo.bar.0`, optional access `foo?`

## Script Template

Declare flags in the `main` signature. Do **not** manually parse `--flags` from
`...args`; Nushell consumes declared flags before positional/rest args and rejects
unknown flags.

```nu
#!/usr/bin/env nu

def main [
  --draft             # boolean flag
  --desc: string = "" # option with value
  parent?: string
  title?: string
  ...rest: string
] {
  if ($parent == null or $title == null) {
    print -e "Usage: my-script [--draft] [--desc BODY] <PARENT> <TITLE> [REST...]"
    exit 1
  }

  let flag = if $draft { "draft" } else { "todo" }
  print $"flag=($flag) parent=($parent) title=($title) rest=($rest | str join ',')"
}
```

Validate scripts with:

```bash
nu --ide-check 100 path/to/script.nu
nu path/to/script.nu --help
```

## External Commands

Prefix external commands with `^` when a name may conflict with a Nu builtin or
when you want to be explicit.

```nu
^jj status
^git diff --stat
^sed -f replacements.sed input.txt
```

Capture stdout/stderr/exit code:

```nu
let out = (^jj new --no-edit @ -m "msg" out+err>| complete)
if $out.exit_code != 0 {
  print -e $out.stderr
  exit $out.exit_code
}
$out.stdout
```

Pipe to an external command:

```nu
^jj log -r @ -G -T description | ^sed 's/old/new/' | ^jj describe @ --stdin
```

Dynamic external command:

```nu
let command = ["sed" "s/a/A/"]
let program = ($command | first)
let args = ($command | skip 1)
"abc" | run-external $program ...$args
```

## File and Path Tips

```nu
let script_dir = $env.FILE_PWD           # directory of the running script
let helper = ($script_dir | path join "helper.nu")
^nu $helper arg1 arg2
```

Caveat: `source` is parse-time and cannot use a dynamic `$env.FILE_PWD`
expression. For globally-invoked scripts, either keep shared constants inline,
use fixed module paths, or invoke helper scripts with `^nu ($env.FILE_PWD | path
join "helper")`.

Use `save --force` to overwrite:

```nu
$data | to json | save --force output.json
```

## Common Data Operations

```nu
# Select/filter/sort
open users.csv | where active == true | select name email | sort-by name

# Extract column as list vs keep table shape
$table | get name       # list of names
$table | select name    # one-column table

# Add/update columns
$table | insert total { |row| $row.price * $row.qty }
$table | update price { |row| $row.price * 1.1 }

# Group and aggregate
open sales.csv
| group-by --to-table region
| update items { |row| $row.items.amount | math sum }
| rename region total

# Null/empty handling
$list | compact
$table | where amount != "" | update amount { into int }
```

## jq → Nu Quick Map

```nu
# jq '.name'
'{"name":"Alice"}' | from json | get name

# jq '.[] | select(.age > 28) | .name'
open people.json | where age > 28 | get name

# jq 'map(. * 2)'
'[1,2,3]' | from json | each { $in * 2 }

# jq '{name: .name, age: (.age + 5)}'
'{"name":"Alice","age":30}' | from json | {name: $in.name, age: ($in.age + 5)}

# jq 'map(select(. != null))'
'[1,null,3]' | from json | compact

# jq 'group_by(.category) | map({category: .[0].category, sum: map(.value) | add})'
open items.json
| group-by --to-table category
| update items { |row| $row.items.value | math sum }
| rename category sum
```

For more examples, see `references/jq-vs-nu.md`.

## Gotchas

- Use spaces in `let`: `let x = "value"`, not `let x="value"`.
- Interpolation is `$"text ($expr)"`; for literal complex strings, build with `+`
  if interpolation parsing gets confused.
- Parenthesize pipelines used as arguments: `foo ($items | length)`.
- `get col` extracts values; `select col` preserves table rows.
- Empty CSV cells often parse as empty strings, not `null`; filter before numeric conversion.
- Prefer `where`, `each`, `reduce`, `update`, `insert` over manual loops for data pipelines.
- For command status, use `complete`; otherwise a failing external command aborts the script.

## References

- `references/scripting.md` - script signatures, flags, externals, validation
- `references/jq-vs-nu.md` - common jq transformations translated to Nu
- Official cookbook: https://www.nushell.sh/cookbook/jq_v_nushell.html
