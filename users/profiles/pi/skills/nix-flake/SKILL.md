---
name: nix-flake
description: "Creates reproducible builds, manages flake inputs, defines devShells, and builds packages with flake.nix. Use when initializing Nix projects, locking dependencies, or running nix build/develop commands."
metadata:
  related: [nix, nh]
  keywords: ["flake", "nix", "build", "devShell", "lock", "reproducible", "init"]
  requires_tools: [bash]
---

# Nix Flakes

Modern Nix project management with hermeticity through `flake.lock`. Every dependency is locked to a specific revision for reproducibility.

## Project Setup

Initialize a new flake:

```bash
nix flake init                    # Basic flake in current directory
nix flake new hello -t templates#hello  # From template
```

Do not create or modify `flake.lock` unless the user explicitly requests a lock operation or dependency update. Use Nix commands rather than editing the lock file by hand.

Manage dependencies:

```bash
nix flake update                  # Update all inputs in flake.lock
nix flake update nixpkgs          # Update specific input only
nix flake lock                    # Lock missing entries without updating
```

## Building & Running

Always prefix local paths with `path:` to include untracked files. Unless a lock change was explicitly requested, add `--no-write-lock-file`:

```bash
nix build --no-write-lock-file path:.                  # Build default package
nix build --no-write-lock-file path:.#packageName      # Build a specific output
nix run --no-write-lock-file path:.                    # Run the default app
nix run --no-write-lock-file path:.#appName            # Run a specific app
nix run --no-write-lock-file github:numtide/treefmt    # Run from a remote flake
```

## Development Environments

Run commands inside a devShell:

```bash
nix develop --no-write-lock-file path:. --command make build
nix develop --no-write-lock-file path:. --command env  # Check the environment
```

The `--command` flag is required in headless environments to avoid interactive mode.

## Inspecting Flakes

```bash
nix flake show --no-write-lock-file path:.
nix flake metadata --no-write-lock-file path:.
nix eval --no-write-lock-file path:.#packages.x86_64-linux.default.name
```

## Basic Flake Structure

```nix
{
  description = "A basic flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
    in {
      packages.${system}.default = pkgs.hello;
      devShells.${system}.default = pkgs.mkShell {
        buildInputs = [ pkgs.git pkgs.vim ];
      };
    };
}
```

## Best Practices

- Always commit `flake.lock` for reproducibility
- Use `path:` prefix when building local flakes to include untracked files
- Always use `--command` with `nix develop` in scripts and headless environments
- Prefer the repository's documented build/check recipes over these generic examples
