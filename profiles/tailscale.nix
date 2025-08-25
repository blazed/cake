{
  services.tailscale = {
    enable = true;
    interfaceName = "tailscale0";
  };
  networking.firewall.trustedInterfaces = [ "tailscale0" ];
  networking.firewall.checkReversePath = "loose";
}
