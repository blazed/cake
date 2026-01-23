{
  lib,
  pkgs,
  adminUser,
  hostName,
  ...
}:
{
  publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBthY9m7Dxs2I5uvU/UeudSV27X52avhWaSuOaM/urpm";

  imports = [
    ../../profiles/hardware/intel.nix
    ../../profiles/admin-user/user.nix
    ../../profiles/disk/btrfs-on-luks.nix
    ../../profiles/k3s-master.nix
    ../../profiles/download_station.nix
    ../../profiles/nfs.nix
    ../../profiles/server.nix
    ../../profiles/state.nix
    ../../profiles/tailscale.nix
    ../../profiles/uuid_disk_crypt.nix
  ];

  boot.initrd = {
    systemd.enable = true;
    availableKernelModules = [
      "xhci_pci"
      "ahci"
      "mpt3sas"
      "usbhid"
      "usb_storage"
      "sd_mod"
    ];
  };

  networking.interfaces.eno1.useDHCP = true;
  networking.interfaces.eno2.useDHCP = false;
  networking.interfaces.eno3.useDHCP = false;
  networking.interfaces.eno4.useDHCP = false;

  age.secrets = {
    k3s-token = {
      file = ../../secrets/k3s/token.age;
    };
    wg-private = {
      file = ../../secrets/${hostName}/wg-private.age;
    };
    ts = {
      file = ../../secrets/ts.age;
      owner = "1447";
    };
  };

  networking.private-wireguard.enable = true;
  networking.private-wireguard.ips = [
    "10.67.124.179/32"
    "fc00:bbbb:bbbb:bb01::4:7cb2/128"
  ];
  networking.private-wireguard.privateKeyFile = "/run/agenix/wg-private";
  networking.private-wireguard.peers = [
    {
      publicKey = "FKodo9V6BehkNphL+neI0g4/G/cjbZyYhoptSWf3Si4=";
      allowedIPs = [
        "0.0.0.0/0"
        "::0/0"
      ];
      endpoint = "185.204.1.219:51820";
      persistentKeepalive = 25;
    }
  ];

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
