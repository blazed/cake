{
  pkgs,
  config,
  lib,
  ...
}: let
  inherit (lib) mkEnableOption mkOption mkIf types;
  cfg = config.networking.private-wireguard;
  peers = types.submodule {
    options = {
      allowedIPs = mkOption {
        type = types.listOf types.str;
      };
      endpoint = mkOption {
        type = types.str;
      };
      publicKey = mkOption {
        type = types.str;
      };
      persistentKeepalive = mkOption {
        type = types.int;
      };
    };
  };
in {
  options.networking.private-wireguard = {
    enable = mkEnableOption "Enable private wireguard";
    privateKeyFile = mkOption {
      type = types.str;
    };
    interfaceNamespace = mkOption {
      type = types.str;
      default = "private";
    };
    peers = mkOption {
      type = types.listOf peers;
    };
    ips = mkOption {
      type = types.listOf types.str;
    };
  };

  config = mkIf (cfg.enable) {
    networking.wireguard.interfaces.private = {
      inherit (cfg) privateKeyFile interfaceNamespace peers ips;
      preSetup = ''
        ${pkgs.iproute2}/bin/ip netns add ${cfg.interfaceNamespace}
        ${pkgs.iproute2}/bin/ip netns exec private ip link set dev lo up
      '';
    };
  };
}
