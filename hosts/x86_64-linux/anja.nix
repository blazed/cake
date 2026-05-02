{
  config,
  lib,
  hostName,
  ...
}:
{
  publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHFFeGviKto0uzeSJBZglLrAQmpwGqIQie61A6MqmiOT"; # Amelia, change me

  imports = [
    ../../profiles/hardware/apu.nix
    ../../profiles/admin-user/user.nix
    ../../profiles/server.nix
    ../../profiles/state.nix
    ../../profiles/tailscale.nix
    ../../profiles/uuid_disk_crypt.nix
    ../../profiles/zram.nix
  ];

  # APU2 has a single small SATA SSD; skip the 64G swap partition the
  # generic disko-btrfs profile uses (zram covers swap on this box).
  disko.devices.disk.disk1 = {
    device = "/dev/sda";
    type = "disk";
    content = {
      type = "gpt";
      partitions = {
        boot = {
          name = "boot";
          size = "1M";
          type = "EF02";
        };
        luks = {
          size = "100%";
          content = {
            type = "luks";
            name = "encrypted";
            settings.allowDiscards = true;
            passwordFile = "/tmp/disk.key";
            content = {
              type = "btrfs";
              extraArgs = [ "-f" ];
              subvolumes = {
                "/root" = lib.mkIf (!config.ephemeralRoot) {
                  mountOptions = [
                    "compress=zstd"
                    "noatime"
                  ];
                  mountpoint = "/";
                };
                "/nix" = {
                  mountOptions = [
                    "compress=zstd"
                    "noatime"
                  ];
                  mountpoint = "/nix";
                };
                "/keep" = {
                  mountOptions = [
                    "compress=zstd"
                    "noatime"
                  ];
                  mountpoint = "/keep";
                };
              };
            };
          };
        };
      };
    };
  };
  disko.devices.nodev."/" = lib.mkIf config.ephemeralRoot {
    fsType = "tmpfs";
    mountOptions = [
      "size=1G"
      "defaults"
      "mode=755"
    ];
  };
  fileSystems."/keep".neededForBoot = true;

  ephemeralRoot = true;

  boot.initrd = {
    systemd.enable = true;
    availableKernelModules = [
      "ahci"
      "ehci_pci"
      "sd_mod"
      "sdhci_pci"
    ];
  };

  age.secrets = {
    nextdns-profile = {
      file = ../../secrets/${hostName}/nextdns-profile.age;
    };
    ts = {
      file = ../../secrets/ts.age;
      owner = "1447";
    };
  };

  # Router — direct port of the pfSense config, with two intentional
  # behavior changes: IoT (VLAN 20) and guest (VLAN 30) are now isolated
  # from the trusted LAN (pfSense had pass-any on every interface).
  services.router = {
    enable = true;
    externalInterface = "enp2s0";
    internalInterface = "enp3s0";
    trustedInterfaces = [
      "lan"
      "tailscale0"
    ];
    vlans = {
      lan = {
        id = 10;
        interface = "enp3s0";
        address = "10.0.10.1";
        trusted = true;
      };
      iot = {
        id = 20;
        interface = "enp3s0";
        address = "10.0.20.1";
        trusted = false;
      };
      guest = {
        id = 30;
        interface = "enp3s0";
        address = "10.0.30.1";
        trusted = false;
      };
    };
    staticHosts = [
      {
        mac = "24:5a:4c:5a:fe:17";
        ip = "10.0.10.5";
        name = "us-8-150w";
      }
      {
        mac = "80:2a:a8:c6:bd:73";
        ip = "10.0.10.6";
        name = "uap-ac-pro";
      }
    ];
    dotUpstreams = [
      "45.90.28.0"
      "45.90.30.0"
    ];
    dotTlsAuthNameFile = config.age.secrets.nextdns-profile.path;
    dnsMasqSettings = {
      # Match pfSense Unbound's behaviour: never fall back to the system
      # resolver, never accept upstream replies from anywhere except the
      # configured server, and never forward private-IP reverse lookups.
      no-resolv = true;
      bogus-priv = true;
      strict-order = true;
    };
  };

  # Advertise the router as a Tailscale exit node + subnet router for
  # the trusted LAN. The auth key is in the existing ts.age secret.
  services.tailscale = {
    useRoutingFeatures = "both";
    extraUpFlags = [
      "--advertise-exit-node"
      "--advertise-routes=10.0.10.0/24"
    ];
  };

  system.autoUpgrade = {
    enable = true;
    flake = "github:blazed/cake";
    allowReboot = true;
    dates = "04:00";
    randomizedDelaySec = "5min";
    enableSentinel = true;
  };
}
