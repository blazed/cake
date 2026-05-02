{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib)
    mkIf
    mkForce
    splitString
    mkOption
    mkEnableOption
    mapAttrsToList
    filterAttrs
    optionalString
    concatMapStringsSep
    flatten
    unique
    ;
  inherit (builtins)
    head
    tail
    attrNames
    mapAttrs
    concatStringsSep
    elemAt
    genList
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

  cidrToNetmask =
    prefix:
    let
      bitsToOctet =
        b:
        elemAt [
          0
          128
          192
          224
          240
          248
          252
          254
          255
        ] b;
      octets = genList (
        i:
        let
          n = prefix - i * 8;
          bits =
            if n >= 8 then
              8
            else if n < 0 then
              0
            else
              n;
        in
        toString (bitsToOctet bits)
      ) 4;
    in
    concatStringsSep "." octets;

  mkInternal = prefix: ip: rec {
    inherit prefix;
    address = ip;
    base = ipBase ip;
    network = "${base}.0";
    broadcast = "${base}.255";
    netmask = cidrToNetmask prefix;
    rangeStart = "${base}.21";
    rangeEnd = "${base}.254";
  };

  internalInterfaces = {
    ${cfg.internalInterface} = mkInternal cfg.internalInterfacePrefixLength cfg.internalInterfaceIP;
  }
  // mapAttrs (_: conf: mkInternal conf.prefixLength conf.address) cfg.vlans;

  internalInterfaceNames = attrNames internalInterfaces;

  trustedVlanNames = attrNames (filterAttrs (_: v: v.trusted) cfg.vlans);
  untrustedVlanNames = attrNames (filterAttrs (_: v: !v.trusted) cfg.vlans);

  useStubby = cfg.dotUpstreams != [ ];
  stubbyPort = 5453;
  stubbyAddress = "127.0.0.1#${toString stubbyPort}";
  stubbyTemplate = pkgs.writeText "stubby.yml.in" ''
    resolution_type: GETDNS_RESOLUTION_STUB
    dns_transport_list:
      - GETDNS_TRANSPORT_TLS
    tls_authentication: GETDNS_AUTHENTICATION_REQUIRED
    tls_query_padding_blocksize: 128
    edns_client_subnet_private: 1
    round_robin_upstreams: 1
    idle_timeout: 10000
    listen_addresses:
      - 127.0.0.1@${toString stubbyPort}
    upstream_recursive_servers:
    ${concatMapStringsSep "\n" (addr: ''
      - address_data: ${addr}
        tls_auth_name: "@TLS_AUTH_NAME@"'') cfg.dotUpstreams}
  '';
  stubbyRender = pkgs.writeShellScript "router-stubby-render" ''
    set -eu
    AUTH_NAME=$(cat ${lib.escapeShellArg (toString cfg.dotTlsAuthNameFile)})
    umask 027
    sed "s|@TLS_AUTH_NAME@|$AUTH_NAME|g" ${stubbyTemplate} > /run/router-dot/stubby.yml
    chgrp router-dot /run/router-dot/stubby.yml
  '';

  # The parent internalInterface is treated as trusted (it is the router's
  # own management LAN; tagged untrusted VLANs ride on top of it).
  trustedAll = unique ([ cfg.internalInterface ] ++ trustedVlanNames ++ cfg.trustedInterfaces);
  allInternalNames = unique (internalInterfaceNames ++ cfg.trustedInterfaces);
in
{
  options.services.router = with lib.types; {
    enable = mkEnableOption "the router";
    upstreamDnsServers = mkOption {
      type = listOf str;
      default = [
        "9.9.9.9"
        "1.1.1.1"
      ];
      description = ''
        Plain-DNS upstreams. Ignored when `dotUpstreams` is non-empty
        (in which case dnsmasq forwards to a local stubby instance).
      '';
    };
    dotUpstreams = mkOption {
      type = listOf str;
      default = [ ];
      description = ''
        DNS-over-TLS upstream addresses (IPs only). When non-empty:
          * stubby runs locally on `127.0.0.1:${toString stubbyPort}` as a
            DoT-to-plain stub resolver;
          * dnsmasq forwards all queries to stubby instead of
            `upstreamDnsServers`;
          * `dotTlsAuthNameFile` must be set.
        Only IPv4 addresses are useful in this module's default IPv6-off
        configuration.
      '';
    };
    dotTlsAuthNameFile = mkOption {
      type = nullOr path;
      default = null;
      description = ''
        Path to a runtime-readable file (typically an agenix secret)
        containing the TLS server-certificate hostname for `dotUpstreams`.
        For NextDNS this is `<profile-id>.dns.nextdns.io`. The profile id
        is account-identifying and should not live in the Nix store.
      '';
    };
    dnsMasqSettings = mkOption {
      type = attrsOf anything;
      default = { };
      description = "Extra dnsmasq settings";
    };
    externalInterface = mkOption {
      type = str;
      description = "The external interface";
    };
    internalInterface = mkOption {
      type = str;
      description = "The internal interface";
    };
    internalInterfaceIP = mkOption {
      type = str;
      default = "10.0.0.1";
      description = "The internal interface IP";
    };
    internalInterfacePrefixLength = mkOption {
      type = ints.between 0 32;
      default = 24;
      description = "Prefix length for the internal interface subnet";
    };
    trustedInterfaces = mkOption {
      type = listOf str;
      default = [ ];
      description = "Trusted interfaces";
    };
    localDomain = mkOption {
      type = str;
      default = "lan.darkstar.se";
      description = ''
        Local DNS domain. Should be a subdomain of a domain you actually
        own (or `home.arpa` per RFC 8375 if you don't). Avoid fake TLDs
        like `.lan` or `.local` — they can collide with real ones.
      '';
    };
    staticHosts = mkOption {
      default = [ ];
      description = ''
        Static DHCP reservations keyed by MAC address. The IP determines
        which subnet the lease comes from. If `name` is set, the host
        also resolves as `<name>.<localDomain>` via dnsmasq.
      '';
      type = listOf (submodule {
        options = {
          mac = mkOption {
            type = str;
            description = "Client MAC address (e.g. `aa:bb:cc:dd:ee:ff`).";
          };
          ip = mkOption {
            type = str;
            description = "Static IPv4 address to assign.";
          };
          name = mkOption {
            type = nullOr str;
            default = null;
            description = "Optional hostname.";
          };
        };
      });
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
                type = ints.between 0 32;
                description = "prefixLength for the address";
                default = 24;
              };
              trusted = mkOption {
                type = bool;
                default = true;
                description = ''
                  When false, this VLAN is treated as untrusted:
                    - on input, only DNS+DHCP to the router are allowed (no ssh,
                      web UI, etc.);
                    - on forward, trusted interfaces may initiate to it, but it
                      can only reach trusted interfaces via established/related
                      state (IoT-style isolation).
                '';
              };
            };
          }
        )
      );
    };
  };

  config = mkIf cfg.enable (
    let
      # Keys whose values are derived from dedicated module options
      # (localDomain, upstreamDnsServers, vlans, staticHosts, …). Letting
      # dnsMasqSettings silently shadow them would defeat the dedicated
      # options.
      reservedDnsmasqKeys = [
        "server"
        "domain"
        "local"
        "dhcp-range"
        "dhcp-option"
        "dhcp-host"
        # Overriding these would silently break per-VLAN scoping or the
        # tailscale0-style runtime-interface handling.
        "interface"
        "bind-dynamic"
        "bind-interfaces"
      ];
      shadowed = builtins.filter (k: cfg.dnsMasqSettings ? ${k}) reservedDnsmasqKeys;
    in
    {
      # Network/broadcast/range derivation in mkInternal currently assumes a
      # /24-aligned subnet. Fail fast if the user picks a different prefix
      # rather than silently emitting wrong DHCP ranges.
      assertions = [
        {
          assertion = cfg.internalInterfacePrefixLength == 24;
          message = "services.router currently only supports /24 internal subnets (got /${toString cfg.internalInterfacePrefixLength}).";
        }
        {
          assertion = shadowed == [ ];
          message = "services.router.dnsMasqSettings cannot override keys derived from other options: ${concatStringsSep ", " shadowed}. Use the dedicated options instead.";
        }
        {
          assertion = !useStubby || cfg.dotTlsAuthNameFile != null;
          message = "services.router.dotUpstreams requires dotTlsAuthNameFile to be set (the file holds the TLS auth name as it is account-identifying).";
        }
      ]
      ++ mapAttrsToList (name: v: {
        assertion = v.prefixLength == 24;
        message = "services.router.vlans.${name} currently only supports /24 (got /${toString v.prefixLength}).";
      }) cfg.vlans;

      environment.persistence."/keep".directories = [ "/var/lib/dnsmasq" ];

      networking.useDHCP = mkForce false;
      networking.interfaces = {
        ${cfg.externalInterface}.useDHCP = true;
      }
      // (mapAttrs (_: net: {
        useDHCP = false;
        ipv4.addresses = [
          {
            inherit (net) address;
            prefixLength = net.prefix;
          }
        ];
      }) internalInterfaces);

      networking.vlans = mapAttrs (_: conf: {
        inherit (conf) id interface;
      }) cfg.vlans;

      users.users.router-dot = mkIf useStubby {
        isSystemUser = true;
        group = "router-dot";
        description = "stubby DoT resolver fronting services.router";
      };
      users.groups.router-dot = mkIf useStubby { };

      systemd.services.router-dot-resolver = mkIf useStubby {
        description = "Stubby DoT stub resolver for services.router";
        after = [ "network.target" ];
        wantedBy = [ "multi-user.target" ];
        before = [ "dnsmasq.service" ];
        serviceConfig = {
          Type = "simple";
          User = "router-dot";
          Group = "router-dot";
          # ExecStartPre+ runs as root so it can read the agenix-secret
          # auth name; the rendered config is mode 0640 owned by
          # root:router-dot so stubby (running as router-dot) can read it
          # but it stays out of world-readable space.
          ExecStartPre = "+${stubbyRender}";
          ExecStart = "${pkgs.stubby}/bin/stubby -C /run/router-dot/stubby.yml";
          Restart = "on-failure";
          RuntimeDirectory = "router-dot";
          RuntimeDirectoryMode = "0750";
          NoNewPrivileges = true;
          ProtectSystem = "strict";
          ProtectHome = true;
          PrivateTmp = true;
          AmbientCapabilities = "";
        };
      };

      services.dnsmasq.enable = true;
      services.dnsmasq.resolveLocalQueries = true;
      services.dnsmasq.settings = {
        server = if useStubby then [ stubbyAddress ] else cfg.upstreamDnsServers;
        domain = cfg.localDomain;
        local = "/${cfg.localDomain}/";
        # Listen on lo (so the router itself can resolve via 127.0.0.1 from
        # resolveLocalQueries), all internal segments, and any
        # trustedInterfaces (e.g. tailscale0) so trusted clients reach the
        # router's DNS.
        interface = unique ([ "lo" ] ++ internalInterfaceNames ++ cfg.trustedInterfaces);
        # bind-dynamic (instead of bind-interfaces) means dnsmasq follows
        # interfaces appearing/disappearing at runtime — needed for
        # interfaces like tailscale0 that don't exist at boot.
        bind-dynamic = true;
        dhcp-authoritative = true;
        expand-hosts = true;
        dhcp-range = mapAttrsToList (
          iface: c: "set:${iface},${c.rangeStart},${c.rangeEnd},${c.netmask},24h"
        ) internalInterfaces;
        dhcp-option = flatten (
          mapAttrsToList (iface: c: [
            "tag:${iface},option:router,${c.address}"
            "tag:${iface},option:dns-server,${c.address}"
          ]) internalInterfaces
        );
        dhcp-host = map (
          h: concatStringsSep "," ([ h.mac ] ++ lib.optional (h.name != null) h.name ++ [ h.ip ])
        ) cfg.staticHosts;
      }
      // cfg.dnsMasqSettings;

      networking.firewall.enable = mkForce false;

      networking.nftables = {
        enable = true;
        # The build-time `nft -c` check can't validate rules that reference
        # real network devices (flowtable + flow offload), so skip it; the
        # ruleset is exercised on activation and by the integration test.
        checkRuleset = false;
        ruleset = ''
          table inet filter {
            # enable flow offloading for better throughput
            flowtable f {
              hook ingress priority 0;
              devices = { ${concatStringsSep "," (internalInterfaceNames ++ [ cfg.externalInterface ])} };
            }

            chain input {
              type filter hook input priority filter; policy drop;

              # Drop spoofed loopback traffic before the unconditional accept.
              iifname "lo" ip saddr != 127.0.0.0/8 drop
              iifname "lo" accept

              # Standard hygiene: kill malformed/out-of-window packets and
              # source-routed packets before any later accept rule sees them.
              ct state invalid counter drop comment "Drop invalid conntrack state"
              ip option lsrr exists counter drop comment "Drop loose source-routed packets"
              ip option ssrr exists counter drop comment "Drop strict source-routed packets"

              # WAN ingress bogons: nothing arriving from the internet should
              # claim a private/loopback/link-local source. rp_filter=1
              # covers most of this; the explicit rule documents intent.
              iifname "${cfg.externalInterface}" ip saddr {
                10.0.0.0/8,
                172.16.0.0/12,
                192.168.0.0/16,
                127.0.0.0/8,
                169.254.0.0/16,
              } counter drop comment "Drop WAN ingress with bogon source"

              # DNS + DHCP must work on every internal segment, including
              # untrusted VLANs (router is their only resolver / DHCP server).
              iifname { ${concatStringsSep "," allInternalNames} } udp dport { 53, 67 } counter accept comment "Allow DNS+DHCP from internal"
              iifname { ${concatStringsSep "," allInternalNames} } tcp dport 53 counter accept comment "Allow DNS/TCP from internal"

              # Full router access only from trusted interfaces.
              iifname { ${concatStringsSep "," trustedAll} } counter accept comment "Allow trusted local network to access the router"

              iifname "${cfg.externalInterface}" ct state { established, related } counter accept comment "Allow established traffic"
              # When externalInterface uses DHCP the dhclient reply may arrive as
              # ct state new because broadcasts don't always match the original
              # tuple. Allow it explicitly so WAN DHCP can complete.
              iifname "${cfg.externalInterface}" udp sport 67 udp dport 68 counter accept comment "Allow DHCP client traffic from wan"
              iifname "${cfg.externalInterface}" counter drop comment "Drop all other unsolicited from wan"
            }

            chain output {
              type filter hook output priority 100; policy accept;
            }

            chain forward {
              type filter hook forward priority filter; policy drop;

              # Standard hygiene, mirrored from `input`.
              ct state invalid counter drop comment "Drop invalid conntrack state"
              ip option lsrr exists counter drop comment "Drop loose source-routed packets"
              ip option ssrr exists counter drop comment "Drop strict source-routed packets"

              # enable flow offloading for better throughput
              ip protocol { tcp, udp } flow offload @f

              iifname { ${concatStringsSep "," allInternalNames} } oifname { "${cfg.externalInterface}" } counter accept comment "Allow LAN to WAN"
              iifname { "${cfg.externalInterface}" } oifname { ${concatStringsSep "," allInternalNames} } ct state { established, related } counter accept comment "Allow established back to LANs"

              # Free routing within the trusted zone (parent <-> trusted VLAN,
              # trusted VLAN <-> trusted VLAN, etc.).
              iifname { ${concatStringsSep "," trustedAll} } oifname { ${concatStringsSep "," trustedAll} } counter accept comment "Allow trusted-to-trusted forwarding"

              ${optionalString (untrustedVlanNames != [ ]) ''
                iifname { ${concatStringsSep "," trustedAll} } oifname { ${concatStringsSep "," untrustedVlanNames} } counter accept comment "Allow trusted to untrusted VLANs"
                iifname { ${concatStringsSep "," untrustedVlanNames} } oifname { ${concatStringsSep "," trustedAll} } ct state { established, related } counter accept comment "Allow established back from untrusted VLANs"
              ''}
            }
          }

          table ip nat {
            chain prerouting {
              type nat hook prerouting priority dstnat; policy accept;
            }

            chain postrouting {
              type nat hook postrouting priority srcnat; policy accept;
              oifname "${cfg.externalInterface}" masquerade
            }
          }

          # IPv6 is intentionally disabled on this router; this table is a
          # defense-in-depth backstop in case anything bypasses the sysctls.
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

      # Only VLAN sub-interfaces have a `<name>-netdev.service`; the parent
      # physical NIC is brought up by udev before any service runs, so don't
      # add a Wants= for it (would just be a "Unit not found" log spam).
      systemd.services.nftables.wants = mapAttrsToList (name: _: "${name}-netdev.service") cfg.vlans;

      boot.kernel.sysctl = {
        "net.ipv4.conf.all.forwarding" = true;
        "net.ipv6.conf.all.forwarding" = false;

        # standard router hardening
        "net.ipv4.conf.all.rp_filter" = 1;
        "net.ipv4.conf.default.rp_filter" = 1;
        "net.ipv4.conf.all.accept_redirects" = 0;
        "net.ipv4.conf.default.accept_redirects" = 0;
        "net.ipv4.conf.all.send_redirects" = 0;
        "net.ipv4.conf.default.send_redirects" = 0;

        # IPv6 fully off, including on WAN
        "net.ipv6.conf.all.accept_ra" = 0;
        "net.ipv6.conf.all.autoconf" = 0;
        "net.ipv6.conf.all.use_tempaddr" = 0;
        "net.ipv6.conf.default.accept_ra" = 0;
        "net.ipv6.conf.default.autoconf" = 0;
      };
    }
  );
}
