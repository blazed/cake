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
    mapAttrs'
    nameValuePair
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
    netmask = cidrToNetmask prefix;
    rangeStart = "${base}.21";
    rangeEnd = "${base}.254";
  };

  internalInterfaces = {
    ${cfg.internalInterface} = mkInternal cfg.internalInterfacePrefixLength cfg.internalInterfaceIP;
  }
  // mapAttrs (_: conf: mkInternal conf.prefixLength conf.address) cfg.vlans;

  internalInterfaceNames = attrNames internalInterfaces;
  internalInterfaceAddresses = map (n: n.address) (builtins.attrValues internalInterfaces);

  trustedVlanNames = attrNames (filterAttrs (_: v: v.trusted) cfg.vlans);
  untrustedVlanNames = attrNames (filterAttrs (_: v: !v.trusted) cfg.vlans);

  forceDnsVlanNames = attrNames (filterAttrs (_: v: v.forceDns) cfg.vlans);
  hasForceDns = forceDnsVlanNames != [ ];

  hairpinForwards = builtins.filter (f: f.hairpin) cfg.portForwards;
  hasHairpin = hairpinForwards != [ ];

  rateLimitedForwards = builtins.filter (f: f.rateLimitNew != null) cfg.portForwards;

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

  # rp_filter=1 already drops cross-interface spoofing at the routing layer;
  # these explicit per-interface source checks keep the trust boundaries
  # enforced inside the ruleset itself even if that sysctl is ever loosened.
  # 0.0.0.0 stays allowed so DHCP DISCOVER/REQUEST broadcasts reach dnsmasq.
  antiSpoofRules = concatStringsSep "\n              " (
    mapAttrsToList (
      name: net:
      ''iifname "${name}" ip saddr != { ${net.network}/${toString net.prefix}, 0.0.0.0 } counter drop comment "Drop spoofed source on ${name}"''
    ) internalInterfaces
  );
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
    dnsForwarders = mkOption {
      type = attrsOf str;
      default = { };
      example = {
        "tailef5cf.ts.net" = "100.100.100.100";
      };
      description = ''
        Per-domain DNS forwarders, rendered as dnsmasq
        `server=/<domain>/<upstream>` directives. Useful for splitting
        a specific domain (e.g. tailscale's MagicDNS suffix) off to a
        dedicated upstream while leaving the rest of the resolver
        chain untouched. Coexists with `upstreamDnsServers` /
        `dotUpstreams` — those handle everything else.
      '';
    };
    rebindOkDomains = mkOption {
      type = listOf str;
      default = [ ];
      example = [ "internal.example.com" ];
      description = ''
        Extra domains exempted from DNS rebind protection
        (`stop-dns-rebind`) — for public names that legitimately resolve
        to private/CGNAT space upstream (split-horizon DNS, tailnet
        rewrites, …). Domains in `dnsForwarders` are always exempt.
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
    portForwards = mkOption {
      default = [ ];
      description = ''
        WAN-side port forwards. Each entry DNATs traffic arriving on the
        external interface to an internal address:port. The forward chain
        accepts DNAT'd traffic via `ct status dnat`, so no separate filter
        rule is required per forward.
      '';
      type = listOf (submodule {
        options = {
          protocol = mkOption {
            type = enum [ "tcp" "udp" ];
            default = "tcp";
            description = "Transport protocol.";
          };
          port = mkOption {
            type = port;
            description = "External (WAN-side) port to listen on.";
          };
          target = mkOption {
            type = str;
            description = ''
              Internal target as `IP:PORT` (e.g. `10.0.10.14:443`). nftables
              syntax allows the destination port to differ from the WAN port.
            '';
          };
          hairpin = mkOption {
            type = bool;
            default = false;
            description = ''
              Enable NAT reflection (hairpin). When true, trusted-side
              traffic (the parent interface, trusted VLANs and
              `trustedInterfaces`) destined for any of anja's IPs other
              than the configured internal-interface addresses (typically
              the WAN IP) on this port is also DNAT'd to `target`, with a
              postrouting masquerade so the reply comes back through the
              router. Untrusted VLANs never hairpin: the forward chain
              would drop their DNAT'd flows anyway, so they are excluded
              from the DNAT and hit a clean input-chain drop instead.

              Note that hairpin necessarily SNATs the LAN client to the
              router's IP — the application backend will see the router as
              the source, not the real LAN client. To preserve real LAN
              client IP, prefer adding a `services.dnsmasq.settings.address`
              entry that resolves the public hostname to the internal VIP
              directly, skipping the router on the LAN-side path entirely.

              The `ip daddr != <internalInterfaceAddresses>` guard prevents
              hijacking traffic to the router's own LAN IPs (e.g. `ssh
              <router>` from the LAN keeps reaching local SSHD), but you
              should still avoid enabling hairpin on ports the router
              binds locally on the WAN interface.
            '';
          };
          rateLimitNew = mkOption {
            type = nullOr str;
            default = null;
            example = "10/minute burst 20 packets";
            description = ''
              Optional nft `limit rate over` expression applied to NEW
              connections arriving from WAN for this forward; traffic above
              the rate is dropped before the DNAT accept. Established
              connections are unaffected. Useful to keep WAN-exposed ports
              (e.g. forwarded SSH) from collecting brute-force noise.
            '';
          };
        };
      });
    };
    vlans = mkOption {
      default = { };
      type = attrsOf (submodule {
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
          forceDns = mkOption {
            type = bool;
            default = false;
            description = ''
              When true, all plain-DNS traffic (TCP/UDP port 53) from this
              VLAN is transparently redirected to the router's dnsmasq, and
              DoT/DoQ egress (port 853) is blocked so clients fall back to
              plain 53. This stops devices with hardcoded resolvers
              (8.8.8.8 etc. — common on IoT) from bypassing the router's
              DNS filtering. DoH rides on 443 and is indistinguishable from
              HTTPS, so it cannot be caught here; accepted limitation.
            '';
          };
        };
      });
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
        # Derived from dnsForwarders + rebindOkDomains; extra rebind
        # exemptions belong in those options.
        "rebind-domain-ok"
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

      systemd.services = {
        # Only VLAN sub-interfaces have a `<name>-netdev.service`; the
        # parent physical NIC is brought up by udev before any service
        # runs, so don't add a Wants= for it (would just be a
        # "Unit not found" log spam).
        nftables.wants = mapAttrsToList (name: _: "${name}-netdev.service") cfg.vlans;

        router-dot-resolver = mkIf useStubby {
          description = "Stubby DoT stub resolver for services.router";
          after = [ "network.target" ];
          wantedBy = [ "multi-user.target" ];
          before = [ "dnsmasq.service" ];
          # Stubby is the only general upstream dnsmasq has (no-resolv +
          # dotUpstreams), so it must never stay dead: systemd's default
          # start limit (5 in 10s) would otherwise turn a crash loop into a
          # permanent LAN-wide DNS outage.
          startLimitIntervalSec = 0;
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
            Restart = "always";
            RestartSec = 2;
            RuntimeDirectory = "router-dot";
            RuntimeDirectoryMode = "0750";
            NoNewPrivileges = true;
            ProtectSystem = "strict";
            ProtectHome = true;
            PrivateTmp = true;
            AmbientCapabilities = "";
          };
        };

        # A manual `systemctl restart dnsmasq` should pull stubby back up
        # if it was stopped; ordering alone (before=) doesn't start it.
        dnsmasq.wants = mkIf useStubby [ "router-dot-resolver.service" ];
      }
      # Order each VLAN's netdev service after its parent's address
      # configuration. Without this, `<vlan>-netdev.service` can race the
      # parent and run `ip link set <vlan> up` while the parent is still
      # admin-down, failing with "Network is down" — leaving the VLAN
      # without an IP and dnsmasq with nothing to offer DHCP clients.
      // mapAttrs' (
        name: conf:
        nameValuePair "${name}-netdev" {
          after = [ "network-addresses-${conf.interface}.service" ];
          requires = [ "network-addresses-${conf.interface}.service" ];
        }
      ) cfg.vlans;

      services.dnsmasq.enable = true;
      services.dnsmasq.resolveLocalQueries = true;
      services.dnsmasq.settings = {
        server =
          (if useStubby then [ stubbyAddress ] else cfg.upstreamDnsServers)
          ++ (mapAttrsToList (domain: srv: "/${domain}/${srv}") cfg.dnsForwarders);
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
        # DNS rebind protection: strip upstream answers that resolve public
        # names into private space (a hostile domain could otherwise pivot
        # a LAN browser at internal services). Local data (localDomain,
        # `address=` overrides, DHCP names) is not subject to the check,
        # and filtering upstreams that answer 0.0.0.0 for blocked names
        # simply yield empty answers instead — same effect. Deliberately
        # overridable via dnsMasqSettings as an escape hatch.
        stop-dns-rebind = true;
        # dnsForwarders exist precisely to return tailnet/CGNAT-range
        # answers (e.g. MagicDNS 100.x), so they are exempted automatically;
        # rebindOkDomains covers other legitimate private-space answers.
        rebind-domain-ok = map (domain: "/${domain}/") (
          attrNames cfg.dnsForwarders ++ cfg.rebindOkDomains
        );
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
              # With nf_conntrack_tcp_loose=0 mid-stream pickups already
              # classify as invalid; this is the explicit backstop against a
              # new connection whose first packet isn't a SYN (ACK scans).
              tcp flags & (fin|syn|rst|ack) != syn ct state new counter drop comment "Drop new TCP without SYN"
              ip option lsrr exists counter drop comment "Drop loose source-routed packets"
              ip option ssrr exists counter drop comment "Drop strict source-routed packets"

              # WAN ingress bogons: nothing arriving from the internet should
              # claim a private/loopback/link-local/reserved source.
              # rp_filter=1 covers most of this; the explicit rule documents
              # intent. Deliberately absent: 100.64.0.0/10 (a CGNAT ISP
              # legitimately sources gateway traffic from it) and the
              # TEST-NET ranges (near-zero abuse value, and the integration
              # test stages its WAN segment on TEST-NET-2).
              iifname "${cfg.externalInterface}" ip saddr {
                0.0.0.0/8,
                10.0.0.0/8,
                127.0.0.0/8,
                169.254.0.0/16,
                172.16.0.0/12,
                192.168.0.0/16,
                198.18.0.0/15,
                224.0.0.0/4,
                240.0.0.0/4,
              } counter drop comment "Drop WAN ingress with bogon source"

              # Internal segments must source from their own subnet (placed
              # before any accept so spoofed DNS/DHCP is caught too).
              ${antiSpoofRules}

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
              # Rate-limited visibility into what the terminal drops eat;
              # journald picks these up and the observability stack ships
              # them, so scans and misbehaving clients become detectable.
              iifname "${cfg.externalInterface}" limit rate 5/minute burst 10 packets log prefix "router-drop wan-in: "
              iifname "${cfg.externalInterface}" counter drop comment "Drop all other unsolicited from wan"
              limit rate 5/minute burst 10 packets log prefix "router-drop input: "
            }

            chain output {
              type filter hook output priority 100; policy accept;
            }

            chain forward {
              type filter hook forward priority filter; policy drop;

              # Standard hygiene, mirrored from `input`.
              ct state invalid counter drop comment "Drop invalid conntrack state"
              tcp flags & (fin|syn|rst|ack) != syn ct state new counter drop comment "Drop new TCP without SYN"
              ip option lsrr exists counter drop comment "Drop loose source-routed packets"
              ip option ssrr exists counter drop comment "Drop strict source-routed packets"

              # Internal segments must source from their own subnet.
              ${antiSpoofRules}

              # enable flow offloading for better throughput
              ip protocol { tcp, udp } flow offload @f

              # BCP38-style egress hygiene: traffic for private ranges must
              # never leave via the default route (it would leak internal
              # destinations to the ISP whenever an internal route is
              # missing). Reject rather than drop so misconfigured clients
              # fail fast instead of hanging.
              oifname "${cfg.externalInterface}" ip daddr {
                10.0.0.0/8,
                172.16.0.0/12,
                192.168.0.0/16,
                169.254.0.0/16,
              } counter reject with icmp type admin-prohibited comment "Reject private-destined egress to WAN"

              ${optionalString hasForceDns ''
                # forceDns VLANs: no DoT/DoQ egress — reject TCP fast so
                # clients fall back to plain 53 (redirected in prerouting),
                # drop the QUIC variant.
                iifname { ${concatStringsSep "," forceDnsVlanNames} } tcp dport 853 counter reject with tcp reset comment "Block DoT from forceDns VLANs"
                iifname { ${concatStringsSep "," forceDnsVlanNames} } udp dport 853 counter drop comment "Block DoQ from forceDns VLANs"
              ''}
              iifname { ${concatStringsSep "," allInternalNames} } oifname { "${cfg.externalInterface}" } counter accept comment "Allow LAN to WAN"
              iifname { "${cfg.externalInterface}" } oifname { ${concatStringsSep "," allInternalNames} } ct state { established, related } counter accept comment "Allow established back to LANs"

              # Throttle NEW connections to rate-limited forwards before the
              # blanket dnat accept below matches them. `ct original
              # proto-dst` is the pre-DNAT WAN port, so the budget stays
              # per-forward even when forwards share a target.
              ${optionalString (rateLimitedForwards != [ ]) (concatMapStringsSep "\n              " (
                f: ''iifname "${cfg.externalInterface}" meta l4proto ${f.protocol} ct status dnat ct state new ct original proto-dst ${toString f.port} limit rate over ${f.rateLimitNew} counter drop comment "Rate limit new connections to forward ${toString f.port}"''
              ) rateLimitedForwards)}

              # DNAT'd WAN ingress: prerouting rewrites destination, here we
              # accept the resulting forward. `ct status dnat` is set by nftables
              # whenever the connection's first packet was DNAT'd, so this
              # implicitly trusts only the explicit `services.router.portForwards`.
              iifname "${cfg.externalInterface}" ct status dnat counter accept comment "Allow DNAT'd WAN ingress"

              # Free routing within the trusted zone (parent <-> trusted VLAN,
              # trusted VLAN <-> trusted VLAN, etc.).
              iifname { ${concatStringsSep "," trustedAll} } oifname { ${concatStringsSep "," trustedAll} } counter accept comment "Allow trusted-to-trusted forwarding"

              ${optionalString (untrustedVlanNames != [ ]) ''
                iifname { ${concatStringsSep "," trustedAll} } oifname { ${concatStringsSep "," untrustedVlanNames} } counter accept comment "Allow trusted to untrusted VLANs"
                iifname { ${concatStringsSep "," untrustedVlanNames} } oifname { ${concatStringsSep "," trustedAll} } ct state { established, related } counter accept comment "Allow established back from untrusted VLANs"
              ''}
              limit rate 5/minute burst 10 packets log prefix "router-drop forward: "
            }
          }

          table ip nat {
            chain prerouting {
              type nat hook prerouting priority dstnat; policy accept;
              ${optionalString hasForceDns ''
                # forceDns VLANs: hijack any plain-DNS query to the router's
                # own dnsmasq. `redirect` DNATs to the address of the
                # interface the packet arrived on, which dnsmasq listens on,
                # and the input chain already accepts 53 from internal.
                iifname { ${concatStringsSep "," forceDnsVlanNames} } meta l4proto { tcp, udp } th dport 53 counter redirect comment "Force VLAN DNS to router"
              ''}
              ${concatMapStringsSep "\n              " (
                f: ''iifname "${cfg.externalInterface}" ${f.protocol} dport ${toString f.port} dnat to ${f.target}''
              ) cfg.portForwards}
              ${optionalString hasHairpin (concatMapStringsSep "\n              " (
                # Hairpin DNAT: trusted-side traffic for any local IP that
                # isn't an internal-interface address (i.e. the WAN IP) on
                # this port also gets DNAT'd to `target`. The `ip daddr !=`
                # set keeps `client → router-LAN-IP:<port>` reaching the
                # router's own services rather than being hijacked.
                # Untrusted VLANs are deliberately excluded: forward would
                # drop their DNAT'd flows anyway (untrusted→trusted needs
                # established), so skipping the DNAT gives them a clean
                # input-chain drop instead of half-applied NAT.
                f: ''iifname { ${concatStringsSep "," trustedAll} } ip daddr != { ${concatStringsSep "," internalInterfaceAddresses} } fib daddr type local ${f.protocol} dport ${toString f.port} dnat to ${f.target}''
              ) hairpinForwards)}
            }

            chain postrouting {
              type nat hook postrouting priority srcnat; policy accept;
              oifname "${cfg.externalInterface}" masquerade
              ${optionalString hasHairpin ''
                # Hairpin SNAT: a LAN-arriving connection that was DNAT'd in
                # prerouting is now exiting back to a LAN interface. Without
                # masquerade the backend would reply directly to the LAN
                # client (whose source was unchanged), and the client's TCP
                # stack would reject the reply as coming from the wrong
                # address. Masquerading sources the connection from the
                # router so replies traverse it on the way back.
                ct status dnat iifname { ${concatStringsSep "," trustedAll} } oifname { ${concatStringsSep "," allInternalNames} } counter masquerade comment "Hairpin NAT reflection"
              ''}
            }
          }

          # IPv6 is intentionally disabled on this router; this table is a
          # defense-in-depth backstop in case anything bypasses the sysctls.
          table ip6 filter {
            chain input {
              type filter hook input priority 0; policy drop;

              # Interfaces still hold ::1/link-local addresses (the sysctls
              # only stop RA/SLAAC) and glibc prefers ::1 for localhost, so
              # without this exception connections to ::1 hang on a silent
              # drop instead of failing fast.
              iifname "lo" accept
            }

            chain forward {
              type filter hook forward priority 0; policy drop;
            }
          }
        '';
      };



      # systemd-sysctl runs right after systemd-modules-load; without the
      # conntrack module loaded at that point the net.netfilter.* keys don't
      # exist yet and the tcp_loose sysctl below would be silently skipped.
      boot.kernelModules = [ "nf_conntrack" ];

      boot.kernel.sysctl = {
        "net.ipv4.conf.all.forwarding" = true;
        "net.ipv6.conf.all.forwarding" = false;

        # Never let conntrack adopt a TCP connection mid-stream: a bare ACK
        # arriving on WAN would otherwise create an *established* entry and
        # sail through the established-accept rules (ACK-scan stealth
        # bypass). With loose pickup off such packets classify as invalid
        # and hit the ct-invalid drop.
        "net.netfilter.nf_conntrack_tcp_loose" = 0;

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
