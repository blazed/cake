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

`agent-browser` is also installed for interactive browser automation. Its Chrome is Nix-provided, so ignore `agent-browser doctor`'s "No Chrome binary found" warning and **never run `agent-browser install`**; downloaded Chrome builds cannot run on NixOS. Browsing works unjailed, but in jailed Pi it can fail with "CDP response channel closed" — use pi-web-access there.

