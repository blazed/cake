{
  config,
  lib,
  hostName,
  ...
}:
{
  publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMzZVi8exDl4Rq32keNWtMdfSQj2pAM+VlnYIpkupTtD";

  imports = [
    ../../profiles/admin-user/user.nix
    ../../profiles/disk/btrfs-on-luks.nix
    ../../profiles/hardware/apu.nix
    ../../profiles/server.nix
    ../../profiles/state.nix
    ../../profiles/tailscale.nix
    ../../profiles/uuid_disk_crypt.nix
    ../../profiles/zram.nix
  ];

  disk.dosLabel = true;

  virtualisation.docker.enable = lib.mkForce false;

  age.secrets = {
    nextdns-profile = {
      file = ../../secrets/${hostName}/nextdns-profile.age;
    };
    ts = {
      file = ../../secrets/ts.age;
      owner = "1447";
    };
  };

  services.router = {
    enable = true;
    externalInterface = "enp4s0";
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
        name = "storage01";
        ip = "10.0.10.2";
        mac = "00:11:32:c8:ea:df";
      }
      {
        name = "us-8-150w";
        ip = "10.0.10.5";
        mac = "24:5a:4c:5a:fe:17";
      }
      {
        name = "uap-ac-pro";
        ip = "10.0.10.6";
        mac = "80:2a:a8:c6:bd:73";
      }
      {
        name = "sophia-kvm";
        ip = "10.0.10.8";
        mac = "ac:1f:6b:6b:6d:32";
      }
      {
        name = "sophia";
        ip = "10.0.10.10";
        mac = "ac:1f:6b:6b:71:c4";
      }
      {
        name = "margot";
        ip = "10.0.10.11";
        mac = "9c:bf:0d:01:0a:d3";
      }
      {
        name = "elsa";
        ip = "10.0.10.12";
        mac = "d0:c6:37:41:d9:ee";
      }
      {
        name = "nicolina";
        ip = "10.0.10.13";
        mac = "24:4b:fe:98:14:aa";
      }
    ];
    dotUpstreams = [
      "45.90.28.0"
      "45.90.30.0"
    ];
    dotTlsAuthNameFile = config.age.secrets.nextdns-profile.path;
    dnsMasqSettings = {
      no-resolv = true;
      bogus-priv = true;
      strict-order = true;
    };
  };

  services.tailscale.auth = {
    enable = true;
    args.advertise-tags = [ "tag:server" ];
    args.ssh = true;
    args.accept-routes = false;
    args.accept-dns = false;
    args.advertise-exit-node = true;
    args.auth-key = "file:/var/run/agenix/ts";
  };

  system.autoUpgrade = {
    enable = false;
    flake = "github:blazed/cake";
    allowReboot = true;
    dates = "04:00";
    randomizedDelaySec = "5min";
    enableSentinel = true;
  };
}
