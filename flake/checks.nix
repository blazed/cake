{ inputs, ... }:
{
  perSystem =
    { pkgs, system, ... }:
    {
      checks = pkgs.lib.optionalAttrs (system == "x86_64-linux") {
        router = pkgs.callPackage ../tests/router.nix { inherit inputs; };
        btrfs-on-luks = pkgs.callPackage ../tests/btrfs-on-luks.nix { };
        jail-leak-audit = pkgs.callPackage ../tests/jail-leak-audit.nix { inherit inputs; };
        jail-jj-workspace = pkgs.callPackage ../tests/jail-jj-workspace.nix { inherit inputs; };
      };
    };
}
