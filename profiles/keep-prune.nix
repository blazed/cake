{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.environment.persistence."/keep" or { };

  entryPath = e: if lib.isAttrs e then (e.directory or e.file) else e;

  prefixed =
    prefix: entries:
    map (e: prefix + "/" + (lib.removePrefix "/" (entryPath e))) entries;

  topPaths = prefixed "" ((cfg.directories or [ ]) ++ (cfg.files or [ ]));

  userPaths = lib.concatMap (
    u:
    prefixed ("/home/" + u) (
      (cfg.users.${u}.directories or [ ]) ++ (cfg.users.${u}.files or [ ])
    )
  ) (lib.attrNames (cfg.users or { }));

  allPaths = lib.naturalSort (lib.unique (topPaths ++ userPaths));

  manifest = pkgs.writeText "keep-prune-manifest" (
    lib.concatStringsSep "\n" allPaths + "\n"
  );

  keep-prune = pkgs.writeShellApplication {
    name = "keep-prune";
    runtimeInputs = with pkgs; [
      coreutils
      gnugrep
      gnused
    ];
    text = ''
      delete=0
      assume_yes=0
      while (( $# )); do
        case $1 in
          -d|--delete) delete=1 ;;
          -y|--yes) assume_yes=1 ;;
          -h|--help)
            cat <<'USAGE'
      Usage: keep-prune [OPTIONS]

      Report data under /keep that the current NixOS impermanence
      configuration no longer declares.

      Options:
        -d, --delete   Remove the reported paths after confirmation
        -y, --yes      Skip the confirmation prompt (only with --delete)
        -h, --help     Show this help
      USAGE
            exit 0
            ;;
          *) echo "keep-prune: unknown argument: $1" >&2; exit 2 ;;
        esac
        shift
      done

      manifest_file=/etc/keep-prune/manifest
      if [[ ! -r $manifest_file ]]; then
        echo "keep-prune: manifest $manifest_file not readable" >&2
        exit 1
      fi
      manifest=$(cat "$manifest_file")
      root=/keep

      if [[ ! -d $root ]]; then
        echo "keep-prune: $root does not exist" >&2
        exit 1
      fi

      if (( delete )) && (( EUID != 0 )); then
        echo "keep-prune: --delete requires root" >&2
        exit 1
      fi

      walk() {
        local path=$1
        local rel=''${path#"$root"}

        if [[ -n $rel ]] && grep -Fxq -- "$rel" <<<"$manifest"; then
          return 0
        fi

        local pat
        if [[ -z $rel ]]; then
          pat='^/'
        else
          pat="^$(printf '%s/' "$rel" | sed 's/[][\\.^$*+?(){}|]/\\&/g')"
        fi

        if grep -qE -- "$pat" <<<"$manifest"; then
          shopt -s nullglob dotglob
          local child
          for child in "$path"/*; do
            [[ -L $child ]] && continue
            walk "$child"
          done
          shopt -u nullglob dotglob
          return 0
        fi

        printf '%s\0' "$path"
      }

      mapfile -d ''' -t stale < <(walk "$root")

      if (( ''${#stale[@]} == 0 )); then
        echo "keep-prune: nothing stale under $root"
        exit 0
      fi

      for p in "''${stale[@]}"; do
        size=$(du -sh -- "$p" 2>/dev/null | cut -f1 || echo "?")
        printf '%8s  %s\n' "$size" "$p"
      done

      if (( ! delete )); then
        echo
        echo "keep-prune: ''${#stale[@]} stale path(s); rerun with --delete to remove"
        exit 0
      fi

      if (( ! assume_yes )); then
        read -r -p "Delete ''${#stale[@]} path(s)? [y/N] " ans
        case $ans in
          y|Y|yes|YES) ;;
          *) echo "aborted"; exit 1 ;;
        esac
      fi

      for p in "''${stale[@]}"; do
        rm -rf -- "$p"
        echo "removed $p"
      done
    '';
  };
in
{
  config = lib.mkIf config.ephemeralRoot {
    environment.etc."keep-prune/manifest".source = manifest;
    environment.systemPackages = [ keep-prune ];
  };
}
