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

  # shortcut-debt: hosts here publish their Tailscale Services with per-profile
  # `tailscale serve --service=svc:<name> --https=443 <target>` oneshot units,
  # not the declarative services.tailscale.serve module. In the v0.0.1 config-file
  # format the endpoint target scheme also decides the *front-end* protocol, so
  # "tcp:443" = "http://127.0.0.1:80" registers plain HTTP on 443 (no TLS) and is
  # then rejected against the https handler tailscaled already persists for the
  # service:
  #   want to serve "http", but port 443 is already serving "https" for svc:frigate
  # Move the profiles onto the module once a tailscale release carries
  # tailscale/tailscale#18381 (front-end protocol in the config file, PR #20116).
  # The switch also needs the retained handlers cleared once (`tailscale serve
  # reset`), because the same check rejects flipping a live port's serve type.
}
