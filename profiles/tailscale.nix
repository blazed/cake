{ pkgs, ... }:
{
  services.tailscale = {
    enable = true;
    interfaceName = "tailscale0";
    package = pkgs.tailscale.overrideAttrs { doCheck = false; };
  };
  networking.firewall.trustedInterfaces = [ "tailscale0" ];
  networking.firewall.checkReversePath = "loose";
}
