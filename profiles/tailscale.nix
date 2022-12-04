{
  services.tailscale.enable = true;

  networking.firewall.trustedInterfaces = ["tailscale0"];
  environment.state."/keep" = {
    directories = [
      "/var/lib/tailscale"
    ];
  };
}
