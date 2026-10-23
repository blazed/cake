#!/usr/bin/env bash
# Run on the target via SSH after a successful nh os boot.
set -euo pipefail

reboot_needed=false
for component in kernel kernel-modules initrd; do
  booted=$(readlink -e "/run/booted-system/$component")
  configured=$(readlink -e "/nix/var/nix/profiles/system/$component")
  if [[ "$booted" != "$configured" ]]; then
    reboot_needed=true
  fi
done
booted_params=$(cat /run/booted-system/kernel-params)
configured_params=$(cat /nix/var/nix/profiles/system/kernel-params)
if [[ "$booted_params" != "$configured_params" ]]; then
  reboot_needed=true
fi

if "$reboot_needed"; then
  sudo -n touch /run/reboot-required
  echo 'Reboot required: created /run/reboot-required on the target host.'
  echo 'The new generation will activate on reboot. Reboot manually if no reboot manager (such as kured) is running.'
else
  sudo -n /nix/var/nix/profiles/system/bin/switch-to-configuration switch
  echo 'New generation activated; no reboot needed.'
fi
