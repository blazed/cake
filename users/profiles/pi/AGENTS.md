# Agent instructions

This machine uses **JJ (Jujutsu)** for version control (git backend) — prefer
`jj` over `git` for all version-control operations.

Add project-agnostic guidance for Pi here. Project-specific instructions belong
in an `AGENTS.md` at the project root (Pi reads both).

## agent-browser

`agent-browser` (interactive browser automation) is installed; its Chrome is
provided by Nix (the package presets `AGENT_BROWSER_EXECUTABLE_PATH`). So ignore
`agent-browser doctor`'s "No Chrome binary found" (false negative) and **never
run `agent-browser install`** (the downloaded Chrome can't run on NixOS).
Browsing works when run unjailed.

This file is managed by Nix (`users/profiles/pi/AGENTS.md`); edit it there and
`switch` to update.
