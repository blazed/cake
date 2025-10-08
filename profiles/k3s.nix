{
  hostName,
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
  };

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

  services.k3s = {
    enable = true;
    after = [
      "tailscale-auth.service"
      "metadata.service"
    ];
    settings = {
      token-file = "/run/agenix/k3s-token";
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
