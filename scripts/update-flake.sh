#!/usr/bin/env bash
# Update flake inputs. When the fully updated lock fails verification, fall
# back to updating inputs one at a time and hold back the ones that break it,
# so a single bad input cannot block the rest of the update PR.
# Held-back inputs are reported as `held=<names>` in $GITHUB_OUTPUT.
set -euo pipefail

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

verify() {
  # The Pi extension check is the one cheap build that input bumps have
  # broken; everything else is only evaluated.
  bash "$(dirname "$0")/eval-all.sh" &&
    nix build --no-link .#checks.x86_64-linux.pi-extensions
}

held=()
cp flake.lock "$tmp/base"
nix flake update

if ! cmp -s flake.lock "$tmp/base" && ! verify; then
  echo "::warning::fully updated flake.lock fails verification; updating inputs one at a time"
  cp "$tmp/base" flake.lock
  if ! verify; then
    echo "::error::flake.lock fails verification before any update; fix main first"
    exit 1
  fi
  for input in $(jq -r '.nodes.root.inputs | keys[]' flake.lock); do
    cp flake.lock "$tmp/good"
    nix flake update "$input"
    cmp -s flake.lock "$tmp/good" && continue
    if ! verify; then
      cp "$tmp/good" flake.lock
      held+=("$input")
      echo "::warning::$input: update fails verification, held back"
    fi
  done
fi

if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
  echo "held=${held[*]}" >>"$GITHUB_OUTPUT"
fi
