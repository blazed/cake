#!/usr/bin/env bash
# Run with: bash tests/upgrade-remote.sh (requires just and nu; no remote access).
set -euo pipefail
repo=$(cd "$(dirname "$0")/.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/bin"
export CALLS="$tmp/calls"

cat > "$tmp/bin/nh" <<'SH'
#!/usr/bin/env bash
printf 'nh %s\n' "$*" >> "$CALLS"
exit "${NH_FAIL:-0}"
SH
cat > "$tmp/bin/ssh" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
[[ "$*" == '-- example bash -se' ]]
echo ssh >> "$CALLS"
exit_code=${SSH_FAIL:-0}
if (( exit_code )); then exit "$exit_code"; fi
bash -se
SH
cat > "$tmp/bin/readlink" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
[[ "$1" == -e ]]
component=${2##*/}
if [[ "${READ_FAIL:-}" == "$component" ]]; then exit 1; fi
if [[ "$2" == /nix/* && "${CHANGED:-}" == "$component" ]]; then
  echo /nix/store/new
else
  echo /nix/store/booted
fi
SH
cat > "$tmp/bin/cat" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
if [[ "${READ_FAIL:-}" == kernel-params ]]; then exit 1; fi
if [[ "$1" == /nix/* && "${CHANGED:-}" == kernel-params ]]; then
  echo changed-params
else
  echo booted-params
fi
SH
cat > "$tmp/bin/sudo" <<'SH'
#!/usr/bin/env bash
case "$*" in
  '-n touch /run/reboot-required') echo sentinel >> "$CALLS" ;;
  '-n /nix/var/nix/profiles/system/bin/switch-to-configuration switch') echo switch >> "$CALLS" ;;
  *) exit 1 ;;
esac
exit "${SUDO_FAIL:-0}"
SH
chmod +x "$tmp/bin/"*
export PATH="$tmp/bin:$PATH"

run() {
  : > "$CALLS"
  just --justfile "$repo/Justfile" upgrade-remote example > "$tmp/output" 2>&1
}
run
grep -q 'nh os boot .*--target-host example --hostname example .* .#example -L' "$CALLS"
grep -q '^ssh$' "$CALLS"
! grep -q '^sentinel$' "$CALLS"
grep -q '^switch$' "$CALLS"
grep -q 'no reboot needed' "$tmp/output"
for component in kernel kernel-modules initrd kernel-params; do
  CHANGED="$component" run
  grep -q '^sentinel$' "$CALLS"
  ! grep -q '^switch$' "$CALLS"
  grep -q 'Reboot required:' "$tmp/output"
  grep -q 'Reboot manually' "$tmp/output"
  if CHANGED=kernel READ_FAIL="$component" run; then
    echo "Expected read failure for $component" >&2; exit 1
  fi
  ! grep -Eq '^(sentinel|switch)$' "$CALLS"
done
if NH_FAIL=1 run; then echo 'Expected boot preparation failure' >&2; exit 1; fi
! grep -q '^ssh$' "$CALLS"
if SSH_FAIL=1 run; then echo 'Expected SSH failure' >&2; exit 1; fi
! grep -Eq '^(sentinel|switch)$' "$CALLS"
if CHANGED=kernel SUDO_FAIL=1 run; then echo 'Expected sentinel failure' >&2; exit 1; fi
! grep -q 'Reboot required:' "$tmp/output"
if SUDO_FAIL=1 run; then echo 'Expected activation failure' >&2; exit 1; fi
! grep -q 'New generation activated' "$tmp/output"
echo 'upgrade-remote checks passed'
