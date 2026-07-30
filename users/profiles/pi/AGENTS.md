# Global Pi agent instructions

These instructions apply to every repository on this machine. Keep them project-agnostic; repository-specific conventions belong in that repository's `AGENTS.md` and should take precedence for local code style, build commands, and tests.

## Instruction precedence

Context files are ordered from general/global to specific/local. When instructions conflict, follow the most specific applicable instruction.

## Tool use

Use tools only when needed. If the user asks only for an explanation, example, or copy-pasteable command, answer directly without executing commands or performing unnecessary validation.

## Version control

All repositories on this machine use **JJ (Jujutsu)** with a Git backend. Prefer `jj` over `git` for version-control operations: status, diff, log, commits, bookmarks/branches, fetch, push, and history inspection. Use `git` only when a tool specifically requires Git or for explicit Git interop.

## Shell command output

The user's interactive shell is **Nushell**. When presenting commands for the user to copy and run:

- Use Nushell-compatible syntax and label shell code fences as `nu`.
- Prefer Nushell pipelines and structured-data commands over POSIX-shell pipelines where appropriate.
- Avoid Bash-only syntax such as `VAR=value command`, `$(...)`, `&&`, `||`, and process substitution unless explicitly providing a Bash command.
- Keep ordinary external CLI invocations unchanged when they are already shell-independent; prefix with `^` only when needed to disambiguate an external command from a Nushell command.
- If a task genuinely requires Bash, say so and provide an explicit `bash -c` invocation or a `bash`-labelled snippet.

These rules apply to commands shown to the user, not to Pi's internal `bash` tool, which executes Bash.
