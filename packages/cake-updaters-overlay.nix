final: prev: let
  inherit (final) writeShellApplication ripgrep buildEnv;

  update-cargo-vendor-sha = writeShellApplication {
    name = "update-cargo-vendor-sha";
    text = ''
      if [ -z "$1" ]; then
          echo "USAGE: $0 <attribute>"
          echo "EXAMPLE: $0 ripgrep"
          exit 1
      fi
      attr="$1"
      path="packages/$attr"/default.nix
      sed -i 's|cargoSha256.*|cargoSha256 = "0000000000000000000000000000000000000000000000000000";|' "$path"
      log="$(mktemp nix-rustbuild-log-"$attr".XXXXXXX)"
      trap 'rm -f $log' EXIT
      nix build .#"$attr" 2>&1 | tee "$log" || true
      cargoSha256="$(grep 'got:.*sha256.*' "$log" | awk '{print $NF}')"
      echo Setting cargoSha256 for "$attr" to "$cargoSha256"
      sed -i "s|cargoSha256.*|cargoSha256 = \"$cargoSha256\";|" "$path"
    '';
  };

  update-all-cargo-vendor-shas = writeShellApplication {
    name = "update-all-cargo-vendor-shas";
    text = ''
      for rpkg in $(${ripgrep}/bin/rg -l cargoSha256 ./packages/*/* | awk -F'/' '{print $3}'); do
        ${update-cargo-vendor-sha}/bin/update-cargo-vendor-sha "$rpkg"
      done
    '';
  };

  update-fixed-output-derivation-sha = writeShellApplication {
    name = "update-fixed-output-derivation-sha";
    text = ''
      if [ -z "$1" ]; then
          echo "USAGE: $0 <attribute>"
          echo "EXAMPLE: $0 argocd-ui"
          exit 1
      fi

      attr="$1"
      path="packages/$attr"/default.nix
      what=outputHash;
      if grep -q "vendorSha256" "$path"; then
        what="vendorSha256"
      fi

      sed -i "s|$what =.*|$what = \"0000000000000000000000000000000000000000000000000000\";|" "$path"

      log="$(mktemp nix-fixed-output-drv-log-"$attr".XXXXXXX)"
      trap 'rm -f $log' EXIT

      nix build .#"$attr" 2>&1 | tee "$log" || true
      hash="$(grep 'got:.*sha256.*' "$log" | awk '{print $NF}')"
      echo Setting "$what" for "$attr" to "$hash"
      sed -i "s|$what =.*|$what = \"$hash\";|" "$path"
    '';
  };

  update-all-fixed-output-derivation-shas = writeShellApplication {
    name = "update-all-fixed-output-derivation-shas";
    text = ''
      for fopkg in $(${ripgrep}/bin/rg -l "outputHash|vendorSha256" ./packages/*/* | awk -F'/' '{print $2}'); do
        ${update-fixed-output-derivation-sha}/bin/update-fixed-output-derivation-sha "$fopkg"
      done
    '';
  };
in {
  cake-updaters = buildEnv {
    name = "cake-updaters";
    paths = [
      update-cargo-vendor-sha
      update-all-cargo-vendor-shas
      update-fixed-output-derivation-sha
      update-all-fixed-output-derivation-shas
    ];
  };
}
