{
  lib,
  pkgs,
  inputs,
  ...
}: let
  inherit (inputs) nixos-hardware;
in {
  imports = [
    "${nixos-hardware}/common/pc/ssd"
    ./defaults.nix
  ];

  networking.usePredictableInterfaceNames = false;
  networking.useDHCP = true;

  environment.systemPackages = [
    pkgs.wget
    pkgs.vim
    pkgs.curl
    pkgs.man-pages
    pkgs.cacert
    pkgs.zip
    pkgs.unzip
    pkgs.jq
    pkgs.git
    pkgs.fd
    pkgs.lsof
    pkgs.fish
    pkgs.wireguard-tools
    pkgs.nfs-utils
    pkgs.iptables
  ];

  boot.kernel.sysctl = {
    "fs.inotify.max_user_watches" = 524288;
    "fs.inotify.max_user_instances" = 8192;
  };

  services.openssh.enable = true;
  services.openssh.settings.PasswordAuthentication = false;

  networking.firewall.allowedTCPPorts = [22];

  services.smartd.enable = true;

  programs.fish.enable = true;
  security.sudo.wheelNeedsPassword = false;

  machinePurpose = lib.mkForce "server";
}
