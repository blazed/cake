# Global Pi agent instructions

These instructions apply to every repository on this machine. Keep them project-agnostic; repository-specific conventions belong in that repository's `AGENTS.md` and should take precedence for local code style, build commands, and tests.

## Version control

All repositories on this machine use **JJ (Jujutsu)** with a Git backend. Prefer `jj` over `git` for version-control operations: status, diff, log, commits, bookmarks/branches, fetch, push, and history inspection. Use `git` only when a tool specifically requires Git or for explicit Git interop.

## Web access

For reading or searching the web, prefer **pi-web-access** (`web_search`, `fetch_content`) — pure HTTP, works inside the jail.

`agent-browser` is also installed for interactive browser automation. Its Chrome is Nix-provided, so ignore `agent-browser doctor`'s "No Chrome binary found" warning and **never run `agent-browser install`**; downloaded Chrome builds cannot run on NixOS. Browsing works unjailed, but in jailed Pi it can fail with "CDP response channel closed" — use pi-web-access there.

