set shell := ["nu", "-c"]

alias help := default

default:
  @just --list -f {{justfile()}} -d {{invocation_directory()}}
  @if (echo {{invocation_directory()}} | str contains "cake") { echo "\n    lint\n    check"}

search query:
  @nix search nixpkgs {{query}} --json | from json | transpose | flatten | select column0 version description | rename --column { column0: attribute }

gc:
  @nix-collect-garbage -d

upgrade flake="github:blazed/cake":
  @rm -rf ~/.cache/nix/fetcher-cache-v1.sqlite*
  @nixos-rebuild boot --flake '{{flake}}' --use-remote-sudo -L
  @if (echo initrd kernel kernel-modules | all { |it| (readlink $"/run/booted-system/($it)") != (readlink $"/nix/var/nix/profiles/system/($it)") }) { echo "The system must be rebooted for the changes to take effect" } else { nixos-rebuild switch --flake '{{flake}}' --use-remote-sudo -L }

switch-remote host="" flake="github:blazed/cake":
  nixos-rebuild switch --flake '{{flake}}' --target-host '{{host}}' --use-remote-sudo -L

build flake="github:blazed/cake":
  @nixos-rebuild build --flake '{{flake}}' --use-remote-sudo -L

[private]
echo +args:
  echo '{{args}}'

[private]
lint:
  @statix check .

[private]
check:
  @nix flake check --impure
