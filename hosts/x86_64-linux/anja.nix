{
  config,
  lib,
  adminUser,
  pkgs,
  hostName,
  ...
}:
{
  publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMzZVi8exDl4Rq32keNWtMdfSQj2pAM+VlnYIpkupTtD";

  imports = [
    ../../profiles/admin-user/user.nix
    ../../profiles/disk/btrfs-on-luks.nix
    ../../profiles/hardware/apu.nix
    ../../profiles/observability.nix
    ../../profiles/server.nix
    ../../profiles/state.nix
    ../../profiles/tailscale.nix
    ../../profiles/uuid_disk_crypt.nix
    ../../profiles/zram.nix
  ];

  modules.observability = {
    enable = true;
    lokiURL = "http://loki.tailef5cf.ts.net:3100/loki/api/v1/push";
  };

  services.prometheus.exporters = {
    blackbox = {
      enable = true;
      listenAddress = "0.0.0.0";
      configFile = pkgs.writeText "blackbox-exporter.yml" ''
        modules:
          dns_udp:
            prober: dns
            timeout: 5s
            dns:
              transport_protocol: udp
              preferred_ip_protocol: ip4
              query_name: example.com
              query_type: A
      '';
    };
    smartctl = {
      enable = true;
      listenAddress = "0.0.0.0";
    };
    smokeping = {
      enable = true;
      listenAddress = "0.0.0.0";
      hosts = [
        "1.1.1.1"
        "9.9.9.9"
      ];
    };
  };

  disk.dosLabel = true;

  virtualisation.docker.enable = lib.mkForce false;
  virtualisation.podman.enable = lib.mkForce false;

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
    # non-VLAN runtime interfaces only; the lan VLAN is trusted via its
    # own `trusted = true` below.
    trustedInterfaces = [ "tailscale0" ];
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
        forceDns = true;
      };
      guest = {
        id = 30;
        interface = "enp3s0";
        address = "10.0.30.1";
        trusted = false;
        forceDns = true;
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
      {
        port = 443;
        target = "10.0.10.14:443";
        hairpin = true;
      }
      {
        port = 22;
        target = "10.0.10.15:22";
        hairpin = true;
        rateLimitNew = "10/minute burst 20 packets";
      }
    ];
    dotUpstreams = [
      "45.90.28.0"
      "45.90.30.0"
    ];
    dotTlsAuthNameFile = config.age.secrets.nextdns-profile.path;
    dnsForwarders = {
      "tailef5cf.ts.net" = "100.100.100.100";
    };
    # Public DNS carries split-horizon exsules.com records pointing into
    # private space (e.g. vault.prd.exsules.com -> a k3s ClusterIP), which
    # stop-dns-rebind would otherwise strip — that broke cert-manager's
    # Vault issuer and with it Istio workload-cert renewal. Exempting our
    # own domain is safe: rebind protection only matters for domains an
    # attacker can answer for.
    rebindOkDomains = [ "exsules.com" ];
    dnsMasqSettings = {
      no-resolv = true;
      bogus-priv = true;
      strict-order = true;
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
    # NOTE: exit-node advertising always includes ::/0 (tailscale has no
    # v4-only flag), but this router intentionally forwards no IPv6 — v6
    # from exit-node clients is blackholed and they fall back to v4 via
    # happy eyeballs; v6-only destinations won't work through this exit.
    args.advertise-exit-node = true;
    args.auth-key = "file:/var/run/agenix/ts";
  };

  users.users.${adminUser.name}.shell = lib.mkForce pkgs.bashInteractive;

  system.autoUpgrade = {
    enable = false;
    flake = "github:blazed/cake";
    allowReboot = true;
    dates = "05:00";
    randomizedDelaySec = "5min";
    enableSentinel = false; # not a k3s node
  };
}
