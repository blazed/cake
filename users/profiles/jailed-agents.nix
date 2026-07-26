# Install bubblewrap-wrapped Claude, Codex, and Pi commands plus the JJ workspace
# launcher. Shared permissions and test-visible definitions live in
# jailed-agents-builders.nix.
{ pkgs, inputs, ... }:
let
  agents = import ./jailed-agents-builders.nix { inherit pkgs inputs; };
in
{
  home.packages = agents.wrappers ++ [ agents.launcher ];
}
