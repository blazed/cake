{ lib, config, hostName, ... }:
let
  cfg = config.services.k3s;
in
{
  services.k3s.enable = true;
  services.k3s.extraFlagsList = [
    "--node-label hostname=${hostName}"
  ];
  services.k3s.disable = [ "traefik" "metrics-server" "servicelb" ];
  services.k3s.disableNetworkPolicy = true;
  networking.firewall.trustedInterfaces = [ "cni0" "flannel.1" "calico+" "cilium+" "lxc+" ];
  environment.state."/keep" = {
    directories = [
      "/etc/rancher"
      "/var/lib/dockershim"
      "/var/lib/rancher"
      "/var/lib/kubelet"
      "/var/lib/cni"
      "/var/lib/containerd"
    ];
  };

  fileSystems."/sys/fs/bpf" = {
    device = "bpffs";
    fsType = "bpf";
    options = [ "rw" "relatime" ];
  };
}
