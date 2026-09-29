#!/usr/bin/env bash
# Bump llama-swap and llama.cpp with nix-update against the real flake packages
# (patches included). A bump that fails is reverted with a warning so the rest of
# the update PR can still land.
set -uo pipefail

latest() {
  # releases/latest is unreliable (llama.cpp marks a 0.x release as latest).
  curl -fsS "https://api.github.com/repos/$1/releases?per_page=20" |
    jq -er --arg p "$2" 'first(.[].tag_name | select(test("^\($p)[0-9]+$")) | ltrimstr($p))'
}

skip() {
  git checkout -- "$1"
  echo "::warning::$2: update failed, skipped (stale patch?)"
}

f=packages/llama-swap-patched.nix
if ! { v=$(latest mostlygeek/llama-swap v) &&
  nix-update --flake --override-filename "$f" --version "$v" --build --subpackage ui llama-swap-patched; }; then
  skip "$f" llama-swap
fi

# A full ROCm build is too heavy here; only check that our patches still apply.
f=packages/llama-cpp-rocm.nix
if ! { v=$(latest ggml-org/llama.cpp b) &&
  nix-update --flake --override-filename "$f" --version "$v" llama-cpp-rocm &&
  nix build --no-link --impure --expr '
    let
      f = builtins.getFlake (toString ./.);
      p = f.packages.x86_64-linux.llama-cpp-rocm;
    in
    f.inputs.nixpkgs.legacyPackages.x86_64-linux.applyPatches {
      name = "llama-cpp-rocm-patched-src";
      inherit (p) src patches;
      postPatch = p.postPatch or "";
    }'; }; then
  skip "$f" llama.cpp
fi
