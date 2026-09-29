# Home Manager activation snippet that deep-merges declared JSON over a
# writable config file, so declared keys win while app-written keys survive.
{ pkgs, lib }:
target: declared: ''
  target="${target}"
  if [[ -n "''${DRY_RUN:-}" ]]; then
    echo "Would merge declared defaults into $target"
  else
    ${pkgs.coreutils}/bin/install -d -m0700 "$(${pkgs.coreutils}/bin/dirname "$target")"
    temporary="$(${pkgs.coreutils}/bin/mktemp "$target.tmp.XXXXXX")"
    trap '${pkgs.coreutils}/bin/rm -f "$temporary"' EXIT
    if [ -f "$target" ]; then
      if ! ${lib.getExe pkgs.jq} -n \
        --slurpfile current "$target" \
        --slurpfile declared ${declared} \
        'if ($current | length) > 1 then error("multiple JSON documents") else ($current[0] // {}) * $declared[0] end' \
        > "$temporary"; then
        echo "warning: invalid existing config; preserving it as $target.invalid" >&2
        ${pkgs.coreutils}/bin/cp "$target" "$target.invalid"
        ${pkgs.coreutils}/bin/cp ${declared} "$temporary"
      fi
    else
      ${pkgs.coreutils}/bin/cp ${declared} "$temporary"
    fi
    ${pkgs.coreutils}/bin/chmod 0600 "$temporary"
    ${pkgs.coreutils}/bin/mv -f "$temporary" "$target"
    trap - EXIT
  fi
''
