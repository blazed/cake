# Nushell Scripting Reference

## Entrypoint and Flags

Use a typed `main` signature. This gives correct `--help`, validation, and flag
parsing.

```nu
#!/usr/bin/env nu

def main [
  --force (-f)        # boolean flag with short alias
  --output (-o): string = "out.json"
  input?: string
  ...rest: string
] {
  if $input == null {
    print -e "Usage: tool.nu [--force] --output <PATH> <INPUT> [REST...]"
    exit 1
  }
  print {force: $force, output: $output, input: $input, rest: $rest}
}
```

Avoid manually parsing `--flags` from `...args`; Nu rejects unknown flags before
your script runs and removes declared flags from rest args.

## Validation

```bash
nu --ide-check 100 script.nu
nu script.nu --help
```

`nu --ide-check` may print type hints; fail only on diagnostics/errors.

## External Commands

```nu
^cmd arg1 arg2
let out = (^cmd arg out+err>| complete)
if $out.exit_code != 0 {
  print -e ($out.stderr | str trim)
  exit $out.exit_code
}
```

`complete` returns:

```nu
{stdout: "...", stderr: "...", exit_code: 0}
```

Piping:

```nu
"abc" | ^sed 's/a/A/'
^jj log -r @ -G -T description | ^jj describe @ --stdin
```

Dynamic external command:

```nu
let command = ["sed" "s/a/A/"]
let program = ($command | first)
let args = ($command | skip 1)
"abc" | run-external $program ...$args
```

## Script-Relative Paths

At runtime:

```nu
let script_dir = $env.FILE_PWD
let helper = ($script_dir | path join "helper.nu")
^nu $helper arg
```

`source` is parse-time and cannot use dynamic `$env.FILE_PWD`. If a script must
run from any cwd, prefer inline constants, fixed module paths, or invoking helper
scripts with `^nu` and `$env.FILE_PWD`.

## Files

```nu
open data.json
open data.csv
$data | to json | save --force output.json
```

When modifying the same file you read, collect first to avoid read/write stream
conflicts:

```nu
let next = (open file.json | update version "2")
$next | save --force file.json
```

## Errors

```nu
if not ($path | path exists) {
  error make {msg: $"missing file: ($path)"}
}

try { open missing.json } catch { |err|
  print -e $"Error: ($err.msg)"
  exit 1
}
```
