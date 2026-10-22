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
        config.permittedInsecurePackages = [ ];
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
            # With structuredAttrs, sphinxHook only reads the first sphinxBuilders
            # element, so khal's man output is never built. Backport the nixpkgs
            # master fix (pulled in by DMS calendar events).
            # TODO: remove once nixpkgs#576662 reaches nixos-unstable.
            khal = prev.khal.overrideAttrs { sphinxBuilders = [ "html man" ]; };
            # Kernel module aggregation now expects a kmodigest .ko.cer next to
            # every external module, which only modules_install produces.
            # Backport the nixpkgs master fix (pulled in by nixos-hardware).
            # TODO: remove once nixpkgs#575818 reaches nixos-unstable.
            kernelPackagesExtensions = prev.kernelPackagesExtensions ++ [
              (_kfinal: kprev: {
                framework-laptop-kmod = kprev.framework-laptop-kmod.overrideAttrs (old: {
                  makeFlags = old.makeFlags ++ [
                    "INSTALL_MOD_PATH=${placeholder "out"}"
                    "INSTALL_MOD_DIR=extra"
                    "DEPMOD=true"
                  ];
                  installTargets = [ "modules_install" ];
                  installPhase = null;
                });
              })
            ];
          })
          # diff-cover-10.5.1's HTML golden-file tests fail with pygments 2.21,
          # which escapes quotes in highlighted output as &quot;. Only the test
          # fixtures are stale; it breaks sqlfluff (pulled in by neovim).
          # TODO: remove once nixpkgs#576855 (10.6.0) reaches nixos-unstable.
          (_final: prev: {
            pythonPackagesExtensions = prev.pythonPackagesExtensions ++ [
              (_pyfinal: pyprev: {
                diff-cover = pyprev.diff-cover.overrideAttrs (old: {
                  disabledTests = (old.disabledTests or [ ]) ++ [
                    "test_added_file_pycodestyle_html"
                    "test_added_file_pyflakes_html"
                    "test_added_file_pylint_html"
                    "test_all_reports"
                    "test_fail_under_html"
                    "test_fail_under_pass_html"
                  ];
                });
              })
            ];
          })
        ];
      };
    };
}
