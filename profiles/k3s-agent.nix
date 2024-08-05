{
  imports = [
    ./k3s.nix
  ];
  services.k3s = {
    enable = true;
    role = "agent";

    settings = {
      node-ip = "\"$(get-iface-ip wlan0)\"";
      flannel-iface = "wlan0";
      token-file = "/run/agenix/k3s-token";
    };
  };
}
