{
  lib,
  pkgs,
  adminUser,
  ...
}:
{
  publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPdjb2aWeDCRA5ncL1ZP31g+wClwV0EaptrnmwwJtHfj";

  imports = [
    ../../profiles/hardware/nuc.nix
    ../../profiles/admin-user/user.nix
    ../../profiles/disk/btrfs-on-luks.nix
    ../../profiles/k3s-agent.nix
    ../../profiles/server.nix
    ../../profiles/state.nix
    ../../profiles/tailscale.nix
    ../../profiles/uuid_disk_crypt.nix
    ../../profiles/wifi.nix
    ../../profiles/zram.nix

    ../../profiles/github-runner.nix
  ];

  age.secrets = {
    k3s-token = {
      file = ../../secrets/k3s/token.age;
    };
    wifi-networks = {
      file = ../../secrets/wifi-networks.age;
    };
    ts = {
      file = ../../secrets/ts.age;
      owner = "1447";
    };
    github-runner = {
      file = ../../secrets/github-runner-token-exsules.age;
      owner = "${toString adminUser.uid}";
    };
  };

  services.k3s.settings = {
    server = "https://sophia.tailef5cf.ts.net:6443";
    node-external-ip = lib.mkForce "\"$(get-iface-ip wlan0)\"";
  };

  users.users.${adminUser.name}.shell = lib.mkForce pkgs.bashInteractive;

  system.autoUpgrade = {
    enable = true;
    flake = "github:blazed/cake";
    allowReboot = true;
    dates = "*:0/15";
    randomizedDelaySec = "5min";
    enableSentinel = true;
  };
}
