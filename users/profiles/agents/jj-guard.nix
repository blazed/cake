# jj wrapper for coding agents that refuses `--allow-private`, so private
# ([task:*]/wip:/draft:) commits can never be pushed by an agent.
{ pkgs, lib }:
pkgs.writeShellApplication {
  name = "jj";
  text = ''
    for argument in "$@"; do
      case "$argument" in
        --allow-private | --allow-private=*)
          echo "jj: --allow-private is disabled for agents" >&2
          exit 2
          ;;
      esac
    done
    exec ${lib.getExe pkgs.jujutsu} "$@"
  '';
}
