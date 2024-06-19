{
  pkgs,
  tailnet,
  hostName,
  ...
}: {
  imports = [
    ./k3s.nix
  ];
  services.k3s = {
    enable = true;
    role = "server";
    after = ["tailscale-auth.service" "tailscaled.service"];

    settings = {
      token-file = "/run/agenix/k3s-token";
      cluster-cidr = "10.244.0.0/16";
      service-cidr = "10.96.0.0/12";
      cluster-dns = "10.96.0.10";
      node-name = hostName;
      advertise-address = "\"$(get-iface-ip tailscale0)\"";
      kube-controller-manager-arg.node-cidr-mask-size = 24;
      node-label."svccontroller.k3s.cattle.io/enablelb" = "true";
      node-label.hostname = hostName;
      secrets-encryption = true;
      tls-san = [hostName "${hostName}.${tailnet}.ts.net"];
    };

    autoDeploy = {
      kured = "${pkgs.kured-yaml}/kured.yaml";
    };
  };
}
