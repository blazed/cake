---
name: nu
description: "Guides Nushell scripts and structured pipelines for JSON, CSV, YAML, TOML, command output, and shell automation. Use when the user asks about Nushell or when adding or editing .nu scripts."
metadata:
  keywords: ["nushell", "nu", "shell", "structured-data", "jq"]
---

# Nushell (`nu`)

Nushell pipelines pass typed records, lists, and tables rather than only text. Prefer Nu for structured data shaping and repository automation when it is available.

## Choose Nu Appropriately

Use Nu for:

- Writing or debugging `.nu` scripts.
- Parsing JSON, CSV, YAML, TOML, or structured command output.
- Replacing fragile `jq`, `awk`, or `sed` pipelines with typed transformations.
- Command-line helpers that benefit from typed arguments and flags.

Use Bash or external tools when exact POSIX behavior, process substitution, byte streams, or an existing project script requires them.

## Core Data Model

```nu
open data.csv
'{"name":"Alice","age":30}' | from json
ls | where size > 10mb | sort-by modified | reverse | first 5
$data | to json | save --force out.json
```

- **record**: keyed fields, such as `{name: Alice, age: 30}`
- **list**: ordered values, such as `[1 2 3]`
- **table**: a list of records with common columns
- **cell path**: nested access such as `foo.bar.0`; optional access uses `foo?`

## Scripts and Validation

Declare flags and arguments in `def main [...]`; do not manually parse declared flags from `...rest`. Read the [scripting reference](references/scripting.md) before writing a nontrivial script.

```nu
#!/usr/bin/env nu

def main [
  --force (-f)
  input: string
] {
  print {input: $input, force: $force}
}
```

Validate scripts with:

```nu
nu --ide-check 100 path/to/script.nu
nu path/to/script.nu --help
```

`nu --ide-check` may emit type hints; fail only on diagnostics or errors.

## External Commands

Prefix an external command with `^` when its name may conflict with a Nu command or when explicit dispatch improves clarity.

```nu
let out = (^jj status | complete)
if $out.exit_code != 0 {
  print -e ($out.stderr | str trim)
  exit $out.exit_code
}
$out.stdout
```

Use `complete` when exit status matters. Otherwise a failing external command may abort the script before custom handling runs.

## Files and Paths

```nu
let script_dir = $env.FILE_PWD
let helper = ($script_dir | path join "helper.nu")
^nu $helper arg1

let next = (open file.json | update version "2")
$next | to json | save --force file.json
```

`source` is parse-time and cannot use a dynamic `$env.FILE_PWD` expression. Invoke a helper with `^nu` when the path is determined at runtime.

## Common Operations

```nu
open users.csv | where active == true | select name email | sort-by name
$table | get name                          # extract a list
$table | select name                       # preserve table rows
$table | insert total { |row| $row.price * $row.qty }
$list | compact
```

For detailed jq translations, read [jq vs Nushell](references/jq-vs-nu.md) instead of reproducing large mappings here.

## Gotchas

- Write `let x = "value"`, not `let x="value"`.
- Interpolation is `$"text ($expr)"`.
- Parenthesize a pipeline used as an argument: `foo ($items | length)`.
- `get col` extracts values; `select col` preserves rows.
- Empty CSV cells are often empty strings rather than `null`; filter before numeric conversion.
- Prefer `where`, `each`, `reduce`, `update`, and `insert` over manual loops.

## References

- [Scripting reference](references/scripting.md) — signatures, flags, external commands, paths, and validation
- [jq vs Nushell](references/jq-vs-nu.md) — common jq transformations in Nu
- [Official jq-to-Nu cookbook](https://www.nushell.sh/cookbook/jq_v_nushell.html)
