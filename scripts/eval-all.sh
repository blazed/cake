#!/usr/bin/env bash
# Evaluate every NixOS host (including those CI does not build) and all
# x86_64-linux packages, checks and dev shells without building them.
# `nix flake check --no-build` cannot do this on a cold store: devenv relies
# on import-from-derivation, which --no-build refuses to realise.
set -euo pipefail

nix eval --impure --json --expr '
  let
    flake = builtins.getFlake (toString ./.);
    drvs = builtins.mapAttrs (_: d: d.drvPath);
  in
  {
    hosts = builtins.mapAttrs (_: c: c.config.system.build.toplevel.drvPath) flake.nixosConfigurations;
    packages = drvs flake.packages.x86_64-linux;
    checks = drvs flake.checks.x86_64-linux;
    devShells = drvs flake.devShells.x86_64-linux;
  }' >/dev/null
