{
  imports = [
    ./auto-upgrade-enhanced.nix
    ./home.nix
    ./host-config.nix
    ./innernet.nix
    ./k3s.nix
    ./private-wireguard.nix
    ./router.nix
    ./server-wireguard.nix
    ./services.nix
    ./tailscale-auth.nix
  ];
}
