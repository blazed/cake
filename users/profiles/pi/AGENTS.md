# Global Pi agent instructions

These instructions apply to every repository on this machine. Keep them project-agnostic; repository-specific conventions belong in that repository's `AGENTS.md` and should take precedence for local code style, build commands, and tests.

## Version control

All repositories on this machine use **JJ (Jujutsu)** with a Git backend. Prefer `jj` over `git` for version-control operations: status, diff, log, commits, bookmarks/branches, fetch, push, and history inspection. Use `git` only when a tool specifically requires Git or for explicit Git interop.

## Shell command output

The user's interactive shell is **Nushell**. When presenting commands for the user to copy and run:

- Use Nushell-compatible syntax and label shell code fences as `nu`.
- Prefer Nushell pipelines and structured-data commands over POSIX-shell pipelines where appropriate.
- Avoid Bash-only syntax such as `VAR=value command`, `$(...)`, `&&`, `||`, and process substitution unless explicitly providing a Bash command.
- Keep ordinary external CLI invocations unchanged when they are already shell-independent; prefix with `^` only when needed to disambiguate an external command from a Nushell command.
- If a task genuinely requires Bash, say so and provide an explicit `bash -c` invocation or a `bash`-labelled snippet.
- When the user asks only for an example or copy-pasteable command, answer directly; do not execute or repeatedly validate it unless requested or genuinely necessary.

These rules apply to commands shown to the user, not to Pi's internal `bash` tool, which executes Bash.

## Web access

For reading or searching the web, prefer **pi-web-access** (`web_search`, `fetch_content`) — pure HTTP, works inside the jail.

## Proton Pass

Use `pass-cli` when credentials are required for an explicitly requested task. The jailed Pi wrapper provides an isolated session directory, filesystem-backed session encryption, and—when configured on the host—an agenix-managed personal access token.

- Before any vault or item operation, run `pass-cli info`. Health and recovery commands are exempt from this pre-check.
- If the session is missing, expired, or reports an authentication error, run `pass-cli logout --force`, then `pass-cli login`, and verify with `pass-cli info` before retrying.
- After login, use `pass-cli vault list --output json` and `pass-cli share list --output json` when access needs verification.
- Set `PROTON_PASS_AGENT_REASON` to a brief, task-specific explanation for every command that requires it, including item reads and writes.
- Prefer `--output json` when results need programmatic parsing.
- Read the complete error output before retrying a failed command.
- Never print, persist, or copy the personal access token into prompts, source files, task notes, logs, or agent memory. Avoid exposing retrieved credentials in responses or command output.