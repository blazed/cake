{
  imports = [
    ./k3s.nix
  ];
  services.k3s = {
    enable = true;
    role = "agent";
    after = ["tailscale-auth.service" "tailscaled.service"];

    settings = {
      node-ip = "\"$(get-iface-ip tailscale0)\"";
      flannel-iface = "tailscale0";
      token-file = "/run/agenix/k3s-token";
    };
  };
}
