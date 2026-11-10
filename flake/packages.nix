{
  inputs,
  self,
  ...
}:
{
  perSystem =
    {
      pkgs,
      lib,
      system,
      ...
    }:
    let
      inherit (lib) mapAttrs';
    in
    {
      packages =
        (mapAttrs' (hostname: config: {
          name = "${hostname}-diskformat";
          value = pkgs.callPackage ../utils/diskformat.nix {
            inherit config;
            inherit lib;
          };
        }) self.nixosConfigurations)
        // {
          cake = pkgs.writeShellApplication {
            name = "cake";
            runtimeInputs = with pkgs; [
              just
              nushell
              statix
              deadnix
              cachix
            ];
            text = ''
              just -f ${../Justfile} -d "$(pwd)" "$@"
            '';
          };
          persway = inputs.persway.packages.${system}.default;
          codex = inputs.llm-agents.packages.${system}.codex;
          dms-greeter = inputs.dank-greeter.packages.${system}.default;
          dms = inputs.dms.packages.${system}.default;
        }
        // lib.optionalAttrs (lib.hasSuffix "-linux" system) {
          # llm-agents packages the daemon without the browser assets.
          paseo = inputs.llm-agents.packages.${system}.paseo.overrideAttrs (old: {
            env = (old.env or { }) // {
              EXPO_NO_TELEMETRY = "1";
              CI = "1";
            };
            postBuild = (old.postBuild or "") + ''
              npm run build:daemon-web-ui
            '';
            postInstall = (old.postInstall or "") + ''
              test -s packages/server/dist/server/web-ui/index.html
              cp -r packages/server/dist/server/web-ui "$out/libexec/paseo/packages/server/dist/server/"
            '';
          });
        }
        // lib.optionalAttrs (system == "x86_64-linux") {
          llama-swap-patched = pkgs.callPackage ../packages/llama-swap-patched.nix { };
          llama-cpp-rocm = pkgs.callPackage ../packages/llama-cpp-rocm.nix { };
          stable-diffusion-cpp-rocm = pkgs.callPackage ../packages/stable-diffusion-cpp-rocm.nix { };
        };
    };
}
