#!/usr/bin/env bash
# Run with: bash tests/update-flake.sh (requires jq; no network or Nix builds).
set -euo pipefail

repo=$(cd "$(dirname "$0")/.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/bin"

# Fake nix: `flake update [input]` bumps inputs to "new"; `eval` fails while
# any input named in $BAD is "new" (or always, with BAD=*).
cat >"$tmp/bin/nix" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
bump() { jq "$1" flake.lock >flake.lock.tmp && mv flake.lock.tmp flake.lock; }
case "$1 $2" in
  "flake update")
    if [[ $# -ge 3 ]]; then
      bump ".nodes[\"$3\"].rev = \"new\""
    else
      bump '.nodes |= with_entries(if .key == "root" then . else .value.rev = "new" end)'
    fi
    ;;
  eval\ *)
    [[ "${BAD:-}" != '*' ]]
    for input in ${BAD:-}; do
      [[ $(jq -r ".nodes[\"$input\"].rev" flake.lock) != new ]]
    done
    ;;
  build\ *) ;;
  *)
    echo "unexpected: nix $*" >&2
    exit 2
    ;;
esac
SH
chmod +x "$tmp/bin/nix"
export PATH="$tmp/bin:$PATH"
cd "$tmp"

reset() {
  cat >flake.lock <<'JSON'
{"nodes":{"root":{"inputs":{"a":"a","b":"b","c":"c"}},"a":{"rev":"old"},"b":{"rev":"old"},"c":{"rev":"old"}}}
JSON
  : >out
}
revs() { jq -r '[.nodes.a.rev, .nodes.b.rev, .nodes.c.rev] | join(" ")' flake.lock; }
export GITHUB_OUTPUT=$tmp/out

reset
bash "$repo/scripts/update-flake.sh"
[[ $(revs) == "new new new" ]]
[[ $(cat out) == "held=" ]]

reset
BAD=b bash "$repo/scripts/update-flake.sh"
[[ $(revs) == "new old new" ]]
[[ $(cat out) == "held=b" ]]

reset
BAD='a c' bash "$repo/scripts/update-flake.sh"
[[ $(revs) == "old new old" ]]
[[ $(cat out) == "held=a c" ]]

reset
if BAD='*' bash "$repo/scripts/update-flake.sh"; then
  echo 'Expected failure when the base lock does not verify' >&2
  exit 1
fi
[[ $(revs) == "old old old" ]]

echo 'update-flake checks passed'
