# Agent instructions

This machine uses **JJ (Jujutsu)** for version control (git backend) — prefer
`jj` over `git` for all version-control operations.

Add project-agnostic guidance for Pi here. Project-specific instructions belong
in an `AGENTS.md` at the project root (Pi reads both).

## Web access

For reading or searching the web, prefer **pi-web-access** (`web_search`,
`fetch_content`) — pure HTTP, works inside the jail.

`agent-browser` (interactive automation) is also installed; its Chrome is
Nix-provided, so ignore `agent-browser doctor`'s "No Chrome binary found"
(false negative) and **never run `agent-browser install`** (the downloaded
Chrome can't run on NixOS). Browsing works unjailed, but in jailed-pi it can
fail with "CDP response channel closed" — use pi-web-access there.

This file is managed by Nix (`users/profiles/pi/AGENTS.md`); edit it there and
`switch` to update.
