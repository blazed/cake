{
  services.tailscale = {
    enable = true;
    interfaceName = "tailscale0";
  };
  # NOTE: both settings below are inert on hosts that force-disable
  # networking.firewall (the router — services.router — replaces it with
  # its own nftables ruleset). There tailscale0 must be trusted explicitly
  # via services.router.trustedInterfaces, and rp_filter is strict (router
  # sysctl) rather than loose; that still works because tailnet routes
  # (100.64.0.0/10) point at tailscale0, so replies pass the strict check.
  networking.firewall.trustedInterfaces = [ "tailscale0" ];
  networking.firewall.checkReversePath = "loose";
}
