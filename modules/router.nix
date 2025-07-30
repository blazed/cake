{
  config,
  lib,
  ...
}:
let
  inherit (lib)
    mkIf
    mkMerge
    splitString
    mkOption
    mkEnableOption
    mapAttrsToList
    ;
  inherit (builtins)
    head
    tail
    attrNames
    mapAttrs
    concatStringsSep
    ;

  cfg = config.services.router;

  ipBase =
    ip:
    let
      s = splitString "." ip;
      a = head s;
      b = head (tail s);
      c = head (tail (tail s));
    in
    "${a}.${b}.${c}";

  internalInterfaces = {
    ${cfg.internalInterface} = rec {
      base = ipBase cfg.internalInterfaceIP;
      address = "${base}.1";
      network = "${base}.0";
      prefixLength = 24;
      netmask = "255.255.255.0";
    };
  }
  // (mapAttrs (name: conf: rec {
    base = ipBase conf.address;
    address = "${base}.1";
    network = "${base}.0";
    prefixLength = 24;
    netmask = "255.255.255.0";
  }) cfg.vlans);

  internalInterfaceNames = attrNames internalInterfaces;
in
{
  options.services.router = with lib.types; {
    enable = mkEnableOption "Enable the router";
    upstreamDnsServers = mkOption {
      type = listOf str;
      description = "List of upstream dns servers";
    };
    dnsMasqSettings = mkOption {
      type = attrsOf anything;
      description = "Extra settings";
    };
    externalInterface = mkOption {
      type = str;
      description = "External interface";
    };
    internalInterface = mkOption {
      type = str;
      description = "Internal interface";
    };
    internalInterfaceIP = mkOption {
      type = str;
      default = "192.168.0.1";
      description = "Internal interface IP";
    };
    trustedInterfaces = mkOption {
      type = listOf str;
      description = "Trusted interfaces";
    };
    vlans = mkOption {
      default = { };
      type = attrsOf (
        submodule (
          { name, ... }:
          {
            options = {
              id = mkOption {
                type = int;
                description = "vlan tag";
              };
              interface = mkOption {
                type = str;
                description = "interface to tag";
              };
              address = mkOption {
                type = str;
                description = "IP Address of vlan";
              };
              prefixLength = mkOption {
                type = int;
                description = "prefixLength for the address";
                default = 24;
              };
            };
          }
        )
      );
    };
  };

  config = mkIf cfg.enable {
    networking.useDHCP = lib.mkForce false;
    networking.interfaces = {
      ${cfg.externalInterface}.useDHCP = true;
    }
    // (mapAttrs (_: net: {
      useDHCP = false;
      ipv4.addresses = [ { inherit (net) address prefixLength; } ];
    }) internalInterfaces);

    networking.vlans = mapAttrs (name: conf: {
      inherit (conf) id interface;
    }) cfg.vlans;

    services.dhcpd4.enable = true;
    services.dhcpd4.interfaces = internalInterfaceNames;
    services.dhcpd4.extraConfig = ''
      option subnet-mask 255.255.255.0;
    ''
    + (concatStringsSep "\n" (
      mapAttrsToList (iface: config: ''
        subnet ${config.network} netmask ${config.netmask} {
          option broadcast-address ${config.base}.255;
          option domain-name-servers ${config.address};
          option routers ${config.address};
          interface ${iface};
          default-lease-time 86400;
          max-lease-time 86400;
          range ${config.base}.10 ${config.base}.128;
        }
      '') internalInterfaces
    ));

    environment.persistence."/keep".directories = [ "/var/lib/dnsmasq" ];

    services.dnsmasq.enable = true;
    services.dnsmasq.resolveLocalQueries = true;
    services.dnsmasq.settings = {
      server = cfg.upstreamDnsServers;
    }
    // cfg.dnsMasqSettings;

    networking.firewall.enable = lib.mkForce false;

    networking.nftables = {
      enable = true;
      ruleset = ''
        table inet filter {
          # enable flow offloading for better throughput
          flowtable f {
            hook ingress priority 0;
            devices = { ${concatStringsSep "," internalInterfaceNames} };
          }

          chain input {
            type filter hook input priority filter; policy drop;

            iifname "lo" accept
            iifname "lo" ip saddr != 127.0.0.0/8 drop
            iifname { ${concatStringsSep "," cfg.trustedInterfaces} } counter accept comment "Allow trusted local network to access the router"
            iifname "${cfg.externalInterface}" ct state { established, related } counter accept comment "Allow established traffic"
            iifname "${cfg.externalInterface}" counter drop comment "Drop all other unsolicited from wan"
          }

          chain output {
            type filter hook output priority 100; policy accept;
          }

          chain forward {
            type filter hook forward priority filter; policy drop;

            # enable flow offloading for better throughput
            ip protocol { tcp, udp } flow offload @f

            iifname { ${
              concatStringsSep "," (internalInterfaceNames ++ cfg.trustedInterfaces)
            } } oifname { "${cfg.externalInterface}" } counter accept comment "Allow LAN to WAN"
            iifname { "${cfg.externalInterface}" } oifname { ${
              concatStringsSep "," (internalInterfaceNames ++ cfg.trustedInterfaces)
            } } ct state { established, related } counter accept comment "Allow established back to LANs"
            iifname { ${concatStringsSep "," cfg.trustedInterfaces} } oifname { "iot" } counter accept comment "Allow trusted LAN to IoT"
            iifname { "iot" } oifname { ${concatStringsSep "," cfg.trustedInterfaces} } ct state { established, related } counter accept comment "Allow established back to LANs"
          }
        }

        table ip nat {
          chain prerouting {
            type nat hook output priority filter; policy accept;
          }

          chain postrouting {
            type nat hook postrouting priority filter; policy accept;
            oifname "${cfg.externalInterface}" masquerade
          }
        }

        table ip6 filter {
          chain input {
            type filter hook input priority 0; policy drop;
          }

          chain forward {
            type filter hook forward priority 0; policy drop;
          }
        }
      '';
    };

    systemd.services.nftables.wants = mkMerge [
      (mapAttrsToList (name: _: "${name}-netdev.service") internalInterfaces)
    ];

    boot.kernel.sysctl."net.ipv4.conf.all.forwarding" = true;
    boot.kernel.sysctl."net.ipv6.conf.all.forwarding" = true;

    # don't automatically configure any ipv6 addresses
    boot.kernel.sysctl."net.ipv6.conf.all.accept_ra" = 0;
    boot.kernel.sysctl."net.ipv6.conf.all.autoconf" = 0;
    boot.kernel.sysctl."net.ipv6.conf.all.use_tempaddr" = 0;

    # allow ipv6 autoconfiguration and temporary address use on wan
    boot.kernel.sysctl."net.ipv6.conf.${cfg.externalInterface}.accept_ra" = 2;
    boot.kernel.sysctl."net.ipv6.conf.${cfg.externalInterface}.autoconf" = 1;
  };
}
