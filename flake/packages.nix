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
        // lib.optionalAttrs (system == "x86_64-linux") {
          llama-swap-patched = pkgs.callPackage ../packages/llama-swap-patched.nix { };
          llama-cpp-rocm = pkgs.callPackage ../packages/llama-cpp-rocm.nix { };
        };
    };
}
