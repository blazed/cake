{ inputs, lib, pkgs, ... }:
let
  kernelPkgs = import inputs.nixpkgs-kernel {
    system = pkgs.stdenv.hostPlatform.system;
    inherit (pkgs) config;
  };
in
{
  # Opt in by importing this profile on a host; it is intentionally not imported globally.
  boot.kernelPackages = lib.mkForce kernelPkgs.linuxPackages_7_1;
}
