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
    portForwards = [
      # HTTPS → istio-gateway (Cilium L2 VIP). Hairpin enabled as a
      # safety net for LAN clients that bypass anja's dnsmasq (e.g.
      # browsers using DoH); known WAN-pointing hostnames have explicit
      # `dnsMasqSettings.address` overrides below to keep real LAN IPs.
      {
        port = 443;
        target = "10.0.10.14:443";
        hairpin = true;
      }
      # SSH → exsules-ssh on its own VIP .15. Cilium's lbipam can't
      # share a VIP across services that select different pods when
      # both run with externalTrafficPolicy=Local (the announcing node
      # might not have local pods for both), so HTTPS and SSH stay on
      # separate VIPs. Hostnames that only do HTTPS get a dnsmasq
      # override to .14 below; hostnames doing both protocols (e.g.
      # git.exsules.dev) keep no override and hairpin from LAN.
      {
        port = 22;
        target = "10.0.10.15:22";
        hairpin = true;
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
      # Split DNS for hostnames whose public A record points at our WAN
      # IP and only serve HTTPS (port 443). LAN clients resolve directly
      # to the istio-gateway VIP, skipping anja entirely — backend sees
      # the real LAN client IP instead of anja's IP (which is what
      # hairpin SNAT would otherwise force).
      #
      # Hostnames that *also* serve SSH (e.g. git.exsules.dev) are
      # intentionally NOT overridden: SSH lives on a separate VIP (.15)
      # because Cilium lbipam can't share a VIP across services with
      # different pod sets under externalTrafficPolicy=Local, and DNS
      # can only return one IP per hostname. LAN traffic to those
      # hostnames goes via hairpin (loses LAN client IP at the backend
      # — appears as anja's 10.0.10.1); external traffic still resolves
      # to the WAN IP and the WAN-side DNAT preserves real client IP.
      address = [
        "/registry.exsules.com/10.0.10.14"
        "/git.exsules.com/10.0.10.14"
      ];
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
    enable = true;
    flake = "github:blazed/cake";
    allowReboot = true;
    # Cluster nodes upgrade between 04:00 and 06:00 (sophia / margot /
    # elsa, in that order). anja goes last, after the cluster has
    # finished, so a router reboot can never interrupt a node mid-rebuild
    # by killing its substituter network access.
    dates = "07:00";
    randomizedDelaySec = "5min";
    enableSentinel = true;
  };
}
