---
name: nix
description: "Runs packages temporarily, creates isolated shell environments, and evaluates Nix expressions. Use when executing tools without installing, debugging derivations, or working with nixpkgs."
metadata:
  related: [nix-flake, nh]
  keywords: ["nix", "shell", "env", "evaluate", "derivation", "nixpkgs", "run", "package"]
  requires_tools: [bash]
---

# Nix

Package manager and functional language for reproducible environments. Run any tool once without installing it permanently.

## Running Packages

Execute a package from `nixpkgs` directly:

```bash
nix run nixpkgs#cowsay -- "Hello!"    # Run with arguments
nix run nixpkgs#hello                  # Simple command
```

For long-running services, wrap in tmux: `tmux new -d 'nix run nixpkgs#some-server'`.

## Shell Environments

Create a temporary shell with specific tools:

```bash
nix shell nixpkgs#git nixpkgs#vim --command git --version
```

## Evaluating Expressions

Debug and inspect Nix expressions in headless environments:

```bash
nix eval --expr '1 + 2'              # Simple expression
nix eval nixpkgs#hello.name          # Inspect an attribute
nix eval --file ./default.nix        # Evaluate a local file
nix eval --expr 'builtins.attrNames (import <nixpkgs> {})'  # List keys
```

## Searching Packages

```bash
nix search nixpkgs python3           # Search by name or description
```

## Formatting Nix Files

```bash
nix fmt                              # Format current directory
nix fmt -- --check                   # Check formatting without changes
```

## Hashes

For fixed-output fetchers, prefer setting the hash to `""` first and letting the failed build report the expected `got:` hash. This avoids guessing hash formats.

Use `nix hash` when you explicitly need local path/file hashing or hash format conversion.

```nix
fetchFromGitHub {
  owner = "nixos";
  repo = "nixpkgs";
  rev = "abc123";
  hash = "";  # let the build tell you the correct hash
}
```

## Shebang Scripts

Use Nix as a script interpreter:

```bash
#!/usr/bin/env nix
#! nix shell nixpkgs#bash nixpkgs#curl --command bash
curl -s https://example.com
```

## Rules

- Use `nix log <derivation>` to debug broken builds
- Use `nix why-depends` to trace dependency chains
- Add `--no-substitute` to force local build when cache is bad
- Use shebang scripts (`#! nix shell ... --command`) for inline nix scripts
