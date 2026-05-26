# cake agent guide

This repository contains **blazed's NixOS configurations**: flake-based NixOS infrastructure using Nix flakes, agenix, disko, home-manager, and JJ (Jujutsu).

This file should stay durable. Prefer stable guidance and pointers to source-of-truth files over inventories that drift.

## Working principles

- Read nearby files before editing and follow the existing style in that area.
- Prefer small, explicit changes over broad refactors.
- Put host-specific logic in `hosts/<system>/<name>.nix`; put reusable behavior in `profiles/` or `modules/`.
- Do not edit generated files, caches, lock files, or secrets unless the user explicitly asks.
- Run the narrowest useful validation for the change and report anything you could not run.

## Source-of-truth files

- `flake.nix` and `flake/*.nix` define flake outputs, checks, packages, host discovery, and CI integration.
- `Justfile` defines common operational commands. Verify recipes there before relying on them.
- `statix.toml` defines Nix lint configuration.
- `tests/` contains NixOS integration tests wired through flake checks.

## Common validation

Prefer current recipes from `Justfile` and flake outputs, but these are the usual checks:

```bash
statix check .             # lint Nix files
deadnix -f .               # find unused Nix code
nix flake check --impure   # full check suite; --impure is required for devenv
```

Validation guidance:

- Documentation-only changes usually do not need builds.
- Nix module/profile/host changes usually warrant `statix check .` plus a focused eval/build when practical.
- Broad flake, package, or test changes may warrant `nix flake check --impure`.
- If a command is expensive, unavailable, or unsafe in the current environment, say so.

## Nix conventions

- Prefer `lib` helpers over raw `builtins` when there is a clear equivalent and nearby code follows that style.
- Modules should define `options` and `config` where applicable, use the usual module argument pattern, and gate optional config with `lib.mkIf`.
- Prefer profiles for reusable configuration clusters and modules for low-level composable behavior.
- Do not bump `system.stateVersion` casually.
- Keep flake inputs deduplicated with `follows` where practical.
- Avoid introducing dead code or unused bindings.

## Safety boundaries

- Do not hand-edit `secrets/*.age`; regenerate them with agenix workflows when needed.
- Do not read or expose plaintext files under `secrets/` unless explicitly required for a local operation.
- Do not manually edit `flake.lock`; update it through Nix tooling when requested.
- Ignore generated/cache paths such as `result`, `.direnv/`, and `.devenv/`.

## Version control

This repository uses **JJ (Jujutsu)** with a Git backend. Prefer `jj` over `git` for version-control operations. For multi-step work, use the jj-todo workflow with empty commits carrying `[task:*]` flags.
