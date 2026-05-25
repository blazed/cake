# Jailed AI coding agents: claude/codex/pi wrapped in bubblewrap (jail.nix) so
# they only see the CWD, their own config dir, the network, the (read-only) Nix
# store, and a curated dev toolset — not SSH keys, cloud creds, or the rest of
# $HOME. The caller's environment + PATH are forwarded (minus secret-looking
# vars) so the agent inherits an active devenv shell. Adds parallel `jailed-*`
# commands alongside the unjailed ones.
#
# The sandbox permission set lives in ./jailed-agents-builders.nix (shared with
# the NixOS tests tests/jail-leak-audit.nix and tests/jail-jj-workspace.nix).
{ pkgs, inputs, ... }:
{
  home.packages = (import ./jailed-agents-builders.nix { inherit pkgs inputs; }).wrappers;
}
