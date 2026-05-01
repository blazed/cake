{ inputs, ... }:
{
  perSystem =
    { pkgs, system, ... }:
    {
      checks = pkgs.lib.optionalAttrs (system == "x86_64-linux") {
        router = pkgs.callPackage ../tests/router.nix { inherit inputs; };
      };
    };
}
