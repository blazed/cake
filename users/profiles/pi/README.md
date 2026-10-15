# Personal Pi project memory

The Home Manager profile installs `pi-memory-init`. From any directory inside a
Git repository (including a colocated JJ repository), run:

```nu
pi-memory-init my-project
```

Choose a distinct bank name for each project. The default API origin is
`https://hindsight-api.tailef5cf.ts.net`; override it with `--server https://host`.
The helper uses tailnet access, not an API token, and requires the API rather
than the Hindsight UI endpoint.

The helper:

- Creates the bank only if absent, leaving existing bank settings untouched.
- Verifies recall through the REST API without adding placeholder memories.
- Adds a project `.pi/mcp.json` connection exposing only `retain`, `recall`, and
  `reflect` through codemode, preserving unrelated MCP settings.
- Creates `.pi/APPEND_SYSTEM.md` with automatic relevant recall and approval-based
  writes. Existing instructions are kept unchanged: add the policy yourself if
  needed. Pi's project append file takes precedence over its global append file.
- Adds the two exact paths to the repository's local Git exclude file before
  writing them. Nothing is committed or added to a shared `.gitignore`.

Reruns are safe. Conflicting Hindsight URLs/tool exposure, tracked configuration,
and symlinked project configuration are refused rather than overwritten. If
recall fails after bank creation, the empty bank remains; fix the service and
rerun. The helper does not delete banks or memories.

Start Pi in the repository root, trust the project configuration, then use
`/reload` and `/mcp` to verify the MCP connection. REST recall verification does
not test Pi's project trust or MCP transport. Banks are context separation, not
access-control boundaries; tailnet clients permitted to access the API can
access other banks too.

## Validation

Offline regression tests use temporary colocated JJ repositories and a local
mock HTTP server; they never contact Hindsight:

```nu
python3 users/profiles/pi/memory-init-test.py
nu --no-config-file --ide-check 100 users/profiles/pi/memory-init.nu
statix check .
```
