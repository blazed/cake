{
  imports = [
    ./k3s.nix
  ];
  services.k3s = {
    enable = true;
    role = "agent";

    settings = {
      token-file = "/run/agenix/k3s-token";
    };
  };
}
