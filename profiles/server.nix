{
  lib,
  pkgs,
  inputs,
  ...
}:
let
  inherit (inputs) nixos-hardware;
in
{
  imports = [
    "${nixos-hardware}/common/pc/ssd"
    ./defaults.nix
  ];

  networking.usePredictableInterfaceNames = false;
  networking.useDHCP = true;

  environment.systemPackages = [ pkgs.nfs-utils ];

  boot.kernel.sysctl = {
    "fs.inotify.max_user_watches" = 524288;
    "fs.inotify.max_user_instances" = 8192;
  };

  services.openssh.enable = true;
  services.openssh.settings.PasswordAuthentication = false;

  networking.firewall.allowedTCPPorts = [ 22 ];

  services.smartd.enable = true;

  programs.fish.enable = true;
  security.sudo.wheelNeedsPassword = false;

  machinePurpose = lib.mkForce "server";
}
