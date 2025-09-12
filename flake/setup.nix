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
          "beekeeper-studio-5.3.4"
        ];
        overlays = [
          inputs.agenix.overlays.default
          inputs.nur.overlays.default
          (
            _final: _prev:
            (filterAttrs (
              name: _: ((match "nu-.*" name == null) && (match "nu_.*" name == null))
            ) config.packages)
          )
        ];
      };
    };
}
