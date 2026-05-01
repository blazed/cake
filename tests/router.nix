{ pkgs, inputs, ... }:
pkgs.testers.runNixOSTest {
  name = "router";

  nodes = {
    router =
      { lib, ... }:
      {
        imports = [
          ../modules/router.nix
          inputs.impermanence.nixosModules.impermanence
        ];

        virtualisation.vlans = [
          1
          2
        ];

        # the router module sets eth1.useDHCP=true; for the test we want a
        # static WAN IP so the "wan" node is reachable without needing an
        # ISP-side DHCP server.
        networking.interfaces.eth1.useDHCP = lib.mkForce false;
        networking.interfaces.eth1.ipv4.addresses = [
          {
            address = "192.168.99.1";
            prefixLength = 24;
          }
        ];

        services.router = {
          enable = true;
          externalInterface = "eth1";
          internalInterface = "eth2";
          internalInterfaceIP = "10.0.0.1";
          upstreamDnsServers = [ "192.168.99.2" ];
          vlans = {
            trustedvl = {
              id = 10;
              interface = "eth2";
              address = "10.0.10.1";
              trusted = true;
            };
            iot = {
              id = 20;
              interface = "eth2";
              address = "10.0.20.1";
              trusted = false;
            };
          };
          staticHosts = [
            {
              mac = "02:00:00:00:00:42";
              ip = "10.0.0.42";
              name = "fixed";
            }
          ];
          dnsMasqSettings = {
            # local answer so the DNS test doesn't depend on an upstream chain
            address = [ "/test.lan.darkstar.se/192.0.2.123" ];
          };
        };

        # internal-only HTTP service on the router; trusted clients should
        # reach it, untrusted clients must not.
        services.nginx = {
          enable = true;
          virtualHosts."router-internal" = {
            listen = [
              {
                addr = "0.0.0.0";
                port = 8080;
              }
            ];
            locations."/".return = ''200 "router internal"'';
          };
        };
      };

    # untagged client on the LAN parent — exercises the static DHCP
    # reservation pinned to its MAC.
    native =
      { lib, ... }:
      {
        virtualisation.vlans = [ 2 ];
        networking.useDHCP = lib.mkForce false;
        networking.interfaces.eth1 = {
          useDHCP = true;
          macAddress = "02:00:00:00:00:42";
        };
        networking.firewall.enable = false;
      };

    # tagged client on VLAN 10 — should be treated as trusted by the router.
    trusted =
      { lib, ... }:
      {
        virtualisation.vlans = [ 2 ];
        networking.useDHCP = lib.mkForce false;
        networking.vlans.lan10 = {
          id = 10;
          interface = "eth1";
        };
        networking.interfaces.eth1.useDHCP = false;
        networking.interfaces.lan10.useDHCP = true;
        networking.firewall.enable = false;
      };

    # tagged client on VLAN 20 — should be treated as untrusted by the router.
    iot =
      { lib, ... }:
      {
        virtualisation.vlans = [ 2 ];
        networking.useDHCP = lib.mkForce false;
        networking.vlans.iot20 = {
          id = 20;
          interface = "eth1";
        };
        networking.interfaces.eth1.useDHCP = false;
        networking.interfaces.iot20.useDHCP = true;
        networking.firewall.enable = false;
      };

    wan =
      { lib, ... }:
      {
        virtualisation.vlans = [ 1 ];
        networking.useDHCP = lib.mkForce false;
        networking.interfaces.eth1.ipv4.addresses = [
          {
            address = "192.168.99.2";
            prefixLength = 24;
          }
        ];
        networking.firewall.enable = false;

        # answer any DNS query with a sentinel IP, so we can verify upstream
        # forwarding works when the router proxies queries here.
        services.dnsmasq.enable = true;
        services.dnsmasq.settings = {
          bind-interfaces = true;
          interface = "eth1";
          no-resolv = true;
          address = [ "/#/192.0.2.250" ];
        };

        services.nginx = {
          enable = true;
          virtualHosts."default" = {
            default = true;
            locations."/".return = ''200 "hi from wan"'';
          };
        };
      };
  };

  testScript = ''
    start_all()

    router.wait_for_unit("nftables.service")
    router.wait_for_unit("dnsmasq.service")
    router.wait_for_unit("nginx.service")
    wan.wait_for_unit("nginx.service")
    wan.wait_for_unit("dnsmasq.service")

    with subtest("native client gets the static DHCP reservation"):
        # the reservation pins MAC 02:00:00:00:00:42 to 10.0.0.42
        native.wait_until_succeeds(
            "ip -4 addr show eth1 | grep -q 'inet 10.0.0.42/'", timeout=60
        )
        native.succeed("ip route get 1.1.1.1 | grep -q '10.0.0.1'")

    with subtest("native client can reach the router"):
        native.succeed("ping -c1 -W2 10.0.0.1")

    with subtest("NAT: native client can reach WAN host"):
        native.succeed("ping -c2 -W5 192.168.99.2")
        native.succeed("curl -sf --max-time 5 http://192.168.99.2/ | grep -q 'hi from wan'")

    with subtest("DNS: router answers locally configured names"):
        native.succeed("getent hosts test.lan.darkstar.se | grep -q 192.0.2.123")

    with subtest("DNS: router itself resolves via 127.0.0.1"):
        # resolveLocalQueries puts `nameserver 127.0.0.1` in /etc/resolv.conf
        # on the router; with bind-dynamic + lo in dnsmasq's interface list,
        # services running on the router (curl, package scripts, etc.)
        # must be able to resolve via the local dnsmasq.
        router.succeed("getent hosts test.lan.darkstar.se | grep -q 192.0.2.123")
        router.succeed("getent hosts something.example | grep -q 192.0.2.250")

    with subtest("DNS: static host name resolves to its reserved IP"):
        # the staticHost reservation also publishes <name>.<localDomain>
        native.succeed("getent hosts fixed.lan.darkstar.se | grep -q 10.0.0.42")

    with subtest("DNS: router forwards unknown queries to upstream"):
        native.succeed("getent hosts something.example | grep -q 192.0.2.250")

    with subtest("WAN cannot initiate connections to LAN"):
        # target the actual reservation IP so the failure is unambiguously
        # the router's forward chain dropping the packet (not ARP/no-host).
        wan.succeed("ip route add 10.0.0.0/24 via 192.168.99.1")
        wan.fail("ping -c1 -W2 10.0.0.42")

    with subtest("trusted VLAN client gets a lease in the trusted subnet"):
        trusted.wait_until_succeeds(
            "ip -4 addr show lan10 | grep -qE 'inet 10\\.0\\.10\\.'", timeout=60
        )

    with subtest("untrusted VLAN client gets a lease in the iot subnet"):
        iot.wait_until_succeeds(
            "ip -4 addr show iot20 | grep -qE 'inet 10\\.0\\.20\\.'", timeout=60
        )

    with subtest("trusted VLAN client can NAT out to WAN"):
        trusted.succeed("curl -sf --max-time 5 http://192.168.99.2/ | grep -q 'hi from wan'")

    with subtest("untrusted VLAN client can NAT out to WAN"):
        iot.succeed("curl -sf --max-time 5 http://192.168.99.2/ | grep -q 'hi from wan'")

    with subtest("trusted-to-trusted: native client can reach trusted VLAN client"):
        # native is on the parent internalInterface (trusted by convention);
        # this exercises the forward path between two trusted segments,
        # which would silently drop without the trustedAll-to-trustedAll rule.
        trusted_ip_for_native = trusted.succeed(
            "ip -4 -o addr show lan10 | awk '{print $4}' | cut -d/ -f1"
        ).strip()
        native.succeed(f"ping -c1 -W2 {trusted_ip_for_native}")

    with subtest("trusted client can reach untrusted client across VLANs"):
        iot_ip = iot.succeed(
            "ip -4 -o addr show iot20 | awk '{print $4}' | cut -d/ -f1"
        ).strip()
        trusted.succeed(f"ping -c1 -W2 {iot_ip}")

    with subtest("untrusted client cannot initiate to trusted client"):
        trusted_ip = trusted.succeed(
            "ip -4 -o addr show lan10 | awk '{print $4}' | cut -d/ -f1"
        ).strip()
        iot.fail(f"ping -c1 -W2 {trusted_ip}")

    with subtest("untrusted client can DNS to router (input chain allows)"):
        iot.succeed("getent hosts fixed.lan.darkstar.se | grep -q 10.0.0.42")

    with subtest("untrusted client cannot reach router services beyond DNS/DHCP"):
        # nginx on 8080 is only reachable from trusted; untrusted is dropped.
        trusted.succeed("curl -sf --max-time 5 http://10.0.10.1:8080/ | grep -q 'router internal'")
        iot.fail("curl -sf --max-time 3 http://10.0.20.1:8080/")

    with subtest("nftables ruleset structure"):
        router.succeed("nft list table ip nat | grep -q 'masquerade'")
        router.succeed("nft list table ip nat | grep -q 'hook prerouting priority dstnat'")
        router.succeed("nft list table ip nat | grep -q 'hook postrouting priority srcnat'")
        # flow offload rule itself may be elided by the kernel (QEMU virtio
        # NICs don't support hardware offload); just check the flowtable
        # is declared.
        router.succeed("nft list table inet filter | grep -q 'flowtable f'")
  '';
}
