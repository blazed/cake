{
  imports = [
    ./k3s.nix
  ];
  services.k3s = {
    enable = true;
    role = "agent";
    settings.node-label."exsules.com/kata-install" = "true";
  };
}
