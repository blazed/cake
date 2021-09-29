{
  imports = [
    ./services.nix
    ./cleanboot.nix
    ./state.nix
    ./sleep-management.nix
    ./k3s.nix
    ./config-from-data.nix
    ./host-config.nix
    ./user-config.nix
    ./private-wireguard.nix
  ];
}
