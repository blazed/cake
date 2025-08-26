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
      inherit (lib // builtins)
        filterAttrs
        mapAttrs
        readDir
        mapAttrs'
        ;
      locallyDefinedPackages = mapAttrs (
        name: _: (pkgs.callPackage (../packages + "/${name}") { inherit inputs; })
      ) (filterAttrs (_filename: type: type == "directory") (readDir ../packages));
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
        // locallyDefinedPackages
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
          candle = inputs.candle.packages.${system}.default;

          inherit (inputs.hyprland.packages.${system})
            hyprland
            hyprland-unwrapped
            xdg-desktop-portal-hyprland
            ;
        };
    };
}
