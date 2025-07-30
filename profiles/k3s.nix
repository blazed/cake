{
  hostName,
  pkgs,
  ...
}:
{
  imports = [
    ../profiles/tailscale.nix
    ../profiles/zram.nix
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
        "tailscale-auth.service"
        "tailscaled.service"
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
      "tailscaled.service"
    ];
    disable = [
      "servicelb"
      "traefik"
      "metrics-server"
    ];
    settings = {
      token-file = "/run/agenix/k3s-token";
      flannel-iface = "tailscale0";
      node-name = hostName;
      node-ip = "\"$(get-iface-ip tailscale0)\"";
      node-external-ip = "\"$(get-iface-ip eth0)\"";
      node-label."topology.kubernetes.io/region" = "\"$REGION\"";
      node-label."topology.kubernetes.io/zone" = "\"$ZONE\"";
      node-label."hostname" = hostName;
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

  networking.firewall.trustedInterfaces = [
    "cni+"
    "flannel.1"
    "calico+"
    "cilium+"
    "lxc+"
  ];
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

  fileSystems."/sys/fs/bpf" = {
    device = "bpffs";
    fsType = "bpf";
    options = [
      "rw"
      "relatime"
    ];
  };
}
