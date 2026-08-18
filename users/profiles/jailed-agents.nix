{ pkgs, inputs, ... }:
let
  agents = import ./jailed-agents-builders.nix { inherit pkgs inputs; };
in
{
  home.packages = agents.wrappers ++ [
    agents.launcher
    agents.hostLauncher
  ];
}
