{
  hostName,
  lib,
  pkgs,
  config,
  ...
}: let
  inherit (lib) options mkIf;
  cfg = config.services.k3s;
in {
  services.k3s.enable = true;
  services.k3s.settings.node-label.hostname = hostName;
  services.k3s.disable = ["traefik" "metrics-server"];
  services.k3s.package = pkgs.k3s_1_29;

  networking.firewall.trustedInterfaces = ["cni0" "flannel.1" "calico+" "cilium+" "lxc+"];
  environment.state."/keep" = {
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
    options = ["rw" "relatime"];
  };
}
