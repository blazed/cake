#!/usr/bin/env bash
# Run with: bash tests/update-ai.sh (requires jq; no network or Nix builds).
set -euo pipefail

repo=$(cd "$(dirname "$0")/.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/bin" "$tmp/profiles"
cp "$repo/profiles/ai.nix" "$tmp/profiles/ai.nix"

cat > "$tmp/bin/curl" <<'SH'
#!/usr/bin/env bash
case "$*" in
  *mostlygeek*) echo '{"tag_name":"v999999"}' ;;
  *) echo '[{"tag_name":"b999999"}]' ;;
esac
SH

cat > "$tmp/bin/nix" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
if [[ "$1" == eval ]]; then
  [[ "${!#}" == '(builtins.getFlake (toString ./.)).inputs.nixpkgs.outPath' ]]
  echo /locked/nixpkgs
  exit 0
fi
[[ "$1" == build ]]
[[ " $* " == *' -I nixpkgs=/locked/nixpkgs '* ]]
expr=${!#}
file=${expr#import }
if grep -q 'llama-swap-vendor' "$file"; then
  grep -q 'pkgs.buildGo127Module' "$file"
  if [[ "${FAIL_VENDOR:-0}" == 1 ]]; then
    echo 'test: vendor build failed before producing a hash' >&2
    exit 1
  fi
fi
# Hash discovery deliberately builds with a fake hash and expects failure.
echo 'error: hash mismatch; got: sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAE=' >&2
exit 1
SH
chmod +x "$tmp/bin/"*
export PATH="$tmp/bin:$PATH"
cd "$tmp"

bash "$repo/scripts/update-ai.sh" >success.log 2>&1
grep -q 'llama-swap: updated .* -> 999999' success.log
grep -q 'llama.cpp: updated .* -> 999999' success.log

cp "$repo/profiles/ai.nix" profiles/ai.nix
if FAIL_VENDOR=1 bash "$repo/scripts/update-ai.sh" >failure.log 2>&1; then
  echo 'Expected the updater to fail on a vendor build error' >&2
  exit 1
fi
grep -q 'test: vendor build failed before producing a hash' failure.log
grep -q 'ERROR: could not determine llama-swap vendorHash' failure.log
cmp "$repo/profiles/ai.nix" profiles/ai.nix

echo 'update-ai checks passed'
