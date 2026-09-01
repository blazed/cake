{
  config,
  hostName,
  lib,
  pkgs,
  ...
}:
{
  imports = [
    ../profiles/tailscale.nix
  ];

  networking.firewall = {
    trustedInterfaces = [
      "lo"
      "cilium_host"
      "cilium_net"
      "cilium_vxlan"
      "lxc+"
      "eth+"
      "wlan+"
    ];
    # tailscaled advertises cilium_host's pod-CIDR address as a WireGuard
    # endpoint, so cluster peers tunnel Tailscale over the vxlan overlay
    # (MTU 1230 < WG's needs → path-MTU blackhole; and the overlay itself
    # can ride tailscale0). Upstream has no exclusion knob
    # (tailscale/tailscale#1552), so drop outbound WG/disco into the pod
    # CIDR; disco then confirms the LAN endpoint instead. Match tailscaled's
    # SO_MARK bypass mark rather than its port — it doesn't reliably keep
    # the configured --port (rebinds to an ephemeral one).
    extraCommands = ''
      iptables -D OUTPUT -d 10.244.0.0/16 -p udp -m mark --mark 0x80000/0xff0000 -j DROP 2>/dev/null || true
      iptables -I OUTPUT -d 10.244.0.0/16 -p udp -m mark --mark 0x80000/0xff0000 -j DROP
    '';
  };

  networking.networkmanager.unmanaged = lib.mkIf config.networking.networkmanager.enable [
    "interface-name:cilium_*"
    "interface-name:lxc*"
  ];

  systemd.services.metadata =
    let
      cloudInitScript = pkgs.writeShellScript "cloud-init" ''
        mkdir -p /run/nixos
        touch /run/nixos/metadata
        cat<<META>/run/nixos/metadata
        NODENAME=${hostName}
        REGION=se
        ZONE=se-a
        META
      '';
    in
    {
      description = "Metadata Service";
      after = [ "network.target" ];
      before = [
        "k3s.service"
      ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = cloudInitScript;
      };
    };

  systemd.services.k3s-node-lifecycle =
    let
      nodeLifecycle = pkgs.writeShellApplication {
        name = "k3s-node-lifecycle";
        runtimeInputs = [
          pkgs.coreutils
          pkgs.kubectl
        ];
        text = ''
          export KUBECONFIG=/run/agenix/k3s-node-lifecycle
          node=${lib.escapeShellArg hostName}

          case "''${1:-}" in
            start)
              until kubectl get node "$node" >/dev/null 2>&1; do
                sleep 5
              done
              kubectl uncordon "$node"
              exec sleep infinity
              ;;
            drain)
              kubectl drain "$node" \
                --ignore-daemonsets \
                --delete-emptydir-data \
                --timeout=10m
              ;;
            *)
              echo "usage: $0 start|drain" >&2
              exit 2
              ;;
          esac
        '';
      };
    in
    {
      description = "Drain and recover the local k3s node";
      unitConfig = {
        ConditionPathExists = "/run/agenix/k3s-node-lifecycle";
        X-StopOnRemoval = false;
      };
      wantedBy = [ "multi-user.target" ];
      wants = [
        "network-online.target"
        "k3s.service"
      ];
      after = [
        "network-online.target"
        "k3s.service"
      ];
      before = [ "shutdown.target" ];
      conflicts = [ "shutdown.target" ];
      restartIfChanged = false;
      serviceConfig = {
        Type = "simple";
        ExecStart = "${nodeLifecycle}/bin/k3s-node-lifecycle start";
        ExecStop = "${nodeLifecycle}/bin/k3s-node-lifecycle drain";
        TimeoutStopSec = "15min";
      };
    };

  systemd.services.k3s = {
    wants = [ "tailscaled.service" ];
    after = [ "tailscaled.service" ];
    preStart = lib.mkBefore ''
      until ${pkgs.iproute2}/bin/ip -o -4 addr show scope global dev tailscale0 >/dev/null 2>&1; do
        sleep 1
      done
    '';
  };

  services.k3s = {
    enable = true;
    package = pkgs.k3s_1_36;
    tokenFile = "/run/agenix/k3s-token";
    after = [
      "tailscale-auth.service"
      "metadata.service"
    ];
    settings = {
      node-name = hostName;
      node-ip = "\"$(get-default-route-ip)\"";
      node-external-ip = "\"$(get-iface-ip tailscale0)\"";
      node-label."topology.kubernetes.io/region" = "\"$REGION\"";
      node-label."topology.kubernetes.io/zone" = "\"$ZONE\"";
      node-label."hostname" = hostName;
      kubelet-arg = "register-with-taints=node.cilium.io/agent-not-ready:NoExecute";
    };
  };

  services.tailscale.auth = {
    enable = true;
    args.advertise-tags = [ "tag:server" ];
    args.ssh = true;
    args.accept-routes = false;
    args.accept-dns = true;
    args.auth-key = "file:/var/run/agenix/ts";
  };

  environment.persistence."/keep" = {
    directories = [
      "/etc/cni"
      "/etc/rancher"
      "/var/lib/cni"
      "/var/lib/containerd"
      "/var/lib/dockershim"
      "/var/lib/kubelet"
      "/var/lib/rancher"
    ];
  };

  fileSystems."/mnt/persistentvolume" = {
    device = "storage01:/volume1/persistentvolume";
    fsType = "nfs";
  };
}
