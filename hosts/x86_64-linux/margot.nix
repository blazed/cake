{
  lib,
  pkgs,
  adminUser,
  ...
}:
{
  publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIH1WMGkVqU0X7XM+JIPvA3vEAnmjJrHApzJYEFXY1pvw";

  imports = [
    ../../profiles/admin-user/user.nix
    ../../profiles/hardware/framework-desktop.nix
    ../../profiles/disk/btrfs-on-luks.nix
    ../../profiles/ai.nix
    ../../profiles/k3s-agent.nix
    ../../profiles/server.nix
    ../../profiles/state.nix
    ../../profiles/tailscale.nix
    ../../profiles/uuid_disk_crypt.nix
    ../../profiles/zram.nix
  ];

  age.secrets = {
    k3s-token = {
      file = ../../secrets/k3s/token.age;
    };
    ts = {
      file = ../../secrets/ts.age;
      owner = "1447";
    };
  };

  services.k3s.settings = {
    server = "https://10.0.10.33:6443";
  };

  users.users.${adminUser.name}.shell = lib.mkForce pkgs.bashInteractive;

  services.fwupd.enable = true;

  boot.initrd.availableKernelModules = [
    "igc"
    "nvme"
    "ahci"
    "usbhid"
  ];

  system.autoUpgrade = {
    enable = true;
    flake = "github:blazed/cake";
    allowReboot = true;
    dates = "05:00";
    randomizedDelaySec = "5min";
    enableSentinel = true;
  };
}
