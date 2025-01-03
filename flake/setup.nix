{
  inputs,
  lib,
  ...
}: {
  perSystem = {
    config,
    system,
    ...
  }: let
    inherit (lib // builtins) filterAttrs match;
  in {
    _module.args.pkgs = import inputs.nixpkgs {
      inherit system;
      config.allowUnfree = true;
      config.permittedInsecurePackages = [
        # Until https://github.com/Sonarr/Sonarr/pull/7443 has been merged
        "aspnetcore-runtime-wrapped-6.0.36"
        "aspnetcore-runtime-6.0.36"
        "dotnet-sdk-6.0.428"
      ];
      overlays = [
        inputs.agenix.overlays.default
        inputs.nur.overlay
        (_final: _prev: (filterAttrs (name: _: ((match "nu-.*" name == null) && (match "nu_.*" name == null))) config.packages))

        (_final: prev: {
          wlroots_river_0_17_2 = prev.wlroots_0_17.overrideAttrs (oa: rec {
            version = "0.17.2";
            src = prev.fetchFromGitLab {
              domain = "gitlab.freedesktop.org";
              owner = "wlroots";
              repo = "wlroots";
              rev = version;
              hash = "sha256-Of9qykyVnBURc5A2pvCMm7sLbnuuG7OPWLxodQLN2Xg=";
            };
            patches = [];
            buildInputs =
              oa.buildInputs
              ++ [
                prev.ffmpeg
                prev.hwdata
                prev.libliftoff
                prev.libdisplay-info
              ];
          });
        })

        (_final: prev: {
          inherit inputs;
          google-cloud-sdk-gke = prev.google-cloud-sdk.withExtraComponents [
            prev.google-cloud-sdk.components.gke-gcloud-auth-plugin
            prev.google-cloud-sdk.components.config-connector
          ];
        })
      ];
    };
  };
}
