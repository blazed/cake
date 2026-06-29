{
  inputs,
  lib,
  ...
}:
{
  perSystem =
    {
      config,
      system,
      ...
    }:
    let
      inherit (lib // builtins) filterAttrs match;
    in
    {
      _module.args.pkgs = import inputs.nixpkgs {
        inherit system;
        config.allowUnfree = true;
        config.permittedInsecurePackages = [
          "beekeeper-studio-5.5.7"
        ];
        overlays = [
          inputs.agenix.overlays.default
          inputs.niri.overlays.niri
          inputs.nur.overlays.default
          (
            _final: _prev:
            (filterAttrs (
              name: _: ((match "nu-.*" name == null) && (match "nu_.*" name == null))
            ) config.packages)
          )
          (_final: prev: {
            openldap = prev.openldap.overrideAttrs {
              doCheck = !prev.stdenv.hostPlatform.isi686;
            };
          })
          # cantarell-fonts-0.311 fails to build with afdko 5.0.1: otfautohint
          # aborts with an AssertionError when a glyph's first stem is a high
          # ghost (NixOS/nixpkgs#535887). Backport the upstream fix
          # (adobe-type-tools/afdko#1844, packaged in NixOS/nixpkgs#536673) and
          # drop afdko's mypy test_type_hints gate, which over-narrows `lo`
          # after the assertion change.
          # TODO: remove once nixpkgs#536673 lands and we flake-update past it.
          (_final: prev: {
            pythonPackagesExtensions = prev.pythonPackagesExtensions ++ [
              (_pyfinal: pyprev: {
                afdko = pyprev.afdko.overrideAttrs (old: {
                  postPatch = (old.postPatch or "") + ''
                    substituteInPlace python/afdko/otfautohint/hinter.py \
                      --replace-fail "assert lo is not None and hi is not None" "assert hi is not None"
                  '';
                  disabledTests = (old.disabledTests or [ ]) ++ [ "test_type_hints" ];
                });
              })
            ];
          })
        ];
      };
    };
}
