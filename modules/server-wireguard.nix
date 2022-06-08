{
  pkgs,
  config,
  lib,
  ...
}: let
  inherit (lib) mkEnableOption mkOption mkIf types;
  cfg = config.networking.server-wireguard;
  peers = types.submodule {
    options = {
      allowedIPs = mkOption {
        type = types.listOf types.str;
      };
      endpoint = mkOption {
        default = null;
        type = types.nullOr types.str;
      };
      publicKey = mkOption {
        type = types.str;
      };
      persistentKeepalive = mkOption {
        default = null;
        type = types.nullOr types.int;
      };
    };
  };
in {
  options.networking.server-wireguard = {
    enable = mkEnableOption "Enable server-wireguard";
    privateKeyFile = mkOption {
      type = types.str;
    };
    peers = mkOption {
      type = types.listOf peers;
    };
    ips = mkOption {
      type = types.listOf types.str;
    };
    cidr = mkOption {
      type = types.str;
      default = "10.0.149.0/24";
    };
    externalInterface = mkOption {
      type = types.str;
      default = "eth0";
    };
    listenPort = mkOption {
      type = types.int;
    };
  };

  config = mkIf cfg.enable {
    networking.wireguard.interfaces.exsules = {
      inherit (cfg) privateKeyFile peers ips listenPort;
      postSetup = ''
        ${pkgs.iptables}/bin/iptables -t nat -A POSTROUTING -s ${cfg.cidr} -o ${cfg.externalInterface} -j MASQUERADE
      '';
      postShutdown = ''
        ${pkgs.iptables}/bin/iptables -t nat -D POSTROUTING -s ${cfg.cidr} -o ${cfg.externalInterface} -j MASQUERADE
      '';
    };
  };
}
