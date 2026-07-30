---
name: nh
description: "Switch NixOS/Home Manager configs with nh — cleaner interface for builds, switches, and garbage collection. Use when running os/home switch or pruning old generations."
metadata:
  related: [nix, nix-flake]
  keywords: ["switch", "home-switch", "nixos", "home-manager", "generation", "prune", "nh"]
---

# nh (Nix Helper)

Cleaner interface for Nix operations — builds, switches, and garbage collection with readable output.

## Before Running nh

- Read the repository's `AGENTS.md`, `Justfile`, or equivalent source of truth first; prefer its recipes when they differ from this generic reference.
- Run state-changing commands (`switch`, `test`, `boot`, `--update`, rollback, or cleanup) only when the user explicitly requests that operation.
- For validation, prefer `build` or `--dry` over activation. Unless lock changes were also requested, pass `--no-write-lock-file` to every flake-based nh command. Never use `--ask` in a headless run.

## Switching Configuration

Build and activate a configuration:

```bash
nh os switch --no-write-lock-file path:.  # Build, activate, and set boot default
nh os test --no-write-lock-file path:.    # Activate temporarily
nh os build --no-write-lock-file path:.   # Build only
nh os boot --no-write-lock-file path:.    # Set boot default without activating
```

Home Manager:

```bash
nh home switch --no-write-lock-file path:.  # Build and activate Home Manager
nh home build --no-write-lock-file path:.   # Build only
```

macOS with nix-darwin:

```bash
nh darwin switch --no-write-lock-file path:.  # Build and activate nix-darwin
```

Path inference works — `nh os switch` uses the local `flake.nix` in the current directory. Prefix local flake paths with `path:` to include untracked files.

## Maintenance & Cleanup

Clean the Nix store and old generations:

```bash
nh clean all --keep-since 7d  # Remove profiles older than 7 days
nh clean user --keep 5        # Keep last 5 user profiles
nh clean all                  # Full garbage collection
```

## Searching & Updating

Search available packages:

```bash
nh search ripgrep             # Search by name or description
```

Update flake inputs before building:

```bash
nh os switch --update path:.  # Update inputs, then build and switch
```

## Common Options

- `--dry` — show what would happen without making changes
- `--ask` — ask for confirmation (avoid in headless/automated scripts)
