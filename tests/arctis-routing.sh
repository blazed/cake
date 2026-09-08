#!/usr/bin/env bash
# Run from the repository root: bash tests/arctis-routing.sh
set -euo pipefail

activation=$(nix build --impure --no-write-lock-file --no-link --print-out-paths --expr '
  let
    flake = builtins.getFlake (toString ./.);
    host = flake.nixosConfigurations.nicolina;
  in host.pkgs.writeShellScript "test-arctis-routing" (
    host.pkgs.lib.removePrefix "run "
      host.config.home-manager.users.blazed.home.activation.arctisRouting.data
  )
')
export XDG_CONFIG_HOME
XDG_CONFIG_HOME=$(mktemp -d)
trap 'rm -rf "$XDG_CONFIG_HOME"' EXIT
root="$XDG_CONFIG_HOME/arctis_manager"

# Fresh setup, then preserve unrelated GUI choices and custom app routes.
"$activation"
grep -q '"spotify": "Arctis_Media"' "$root/routing_overrides.json"
grep -q 'redirect_audio_on_disconnect: true' "$root/settings/general_settings.yaml"
printf '%s\n' '{"Custom Game": "Arctis_Game", "spotify": "Arctis_Game"}' > "$root/routing_overrides.json"
printf '%s\n' 'hrir_id: none' 'redirect_audio_on_disconnect: false' > "$root/settings/general_settings.yaml"
"$activation"
grep -q '"Custom Game": "Arctis_Game"' "$root/routing_overrides.json"
grep -q '"spotify": "Arctis_Media"' "$root/routing_overrides.json"
grep -q 'hrir_id: none' "$root/settings/general_settings.yaml"
grep -q 'redirect_audio_on_disconnect: true' "$root/settings/general_settings.yaml"
cp "$root/routing_overrides.json" "$XDG_CONFIG_HOME/expected.json"
"$activation"
cmp "$root/routing_overrides.json" "$XDG_CONFIG_HOME/expected.json"

# Invalid user data must fail without replacing the file.
printf '%s\n' '[]' > "$root/routing_overrides.json"
if "$activation"; then
  echo 'Expected invalid configuration to be rejected' >&2
  exit 1
fi
test "$(cat "$root/routing_overrides.json")" = '[]'
echo 'Arctis routing checks passed'
