{
  imports = [
    ./k3s.nix
  ];
  services.k3s = {
    enable = true;
    role = "agent";
    after = ["tailscale-auth.service" "tailscaled.service"];

    settings = {
      token-file = "/run/agenix/k3s-token";
    };
  };
}
