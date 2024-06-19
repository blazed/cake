{
  adminUser,
  hostName,
  ...
}: {
  publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOrJCuQh8JV7yArBzBL8rGtpKGyvqiXthl1tQmtVmTKg";

  imports = [
    ../../profiles/hardware/nuc.nix
    ../../profiles/admin-user/user.nix
    ../../profiles/disk/btrfs-on-luks.nix
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
    wifi-networks = {
      file = ../../secrets/wifi-networks.age;
    };
  };

  services.k3s.settings.server = "https://sophia.tailef5cf.ts.net:6443";

  system.autoUpgrade = {
    enable = true;
    flake = "github:blazed/cake";
    allowReboot = true;
    dates = "*:0/15";
    randomizedDelaySec = "5min";
    enableSentinel = true;
  };
}
