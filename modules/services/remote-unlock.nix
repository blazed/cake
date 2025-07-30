{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (builtins)
    filter
    getAttr
    length
    foldl'
    ;
  inherit (lib)
    mkEnableOption
    mkOption
    mkIf
    recursiveUpdate
    ;
  inherit (lib.types)
    port
    str
    listOf
    submodule
    ;
  cfg = config.services.remote-unlock;
  enabledCfgs = filter (getAttr "enable") cfg;
  mkRemoteDiskUnlock =
    {
      host,
      port,
      passwordFile,
      identityFile,
      interval,
      ...
    }:
    let
      strPort = toString port;
      name = "remote-unlock-${host}-${strPort}";
    in
    {
      timers.${name} = {
        description = "Remote disk unlock for ${host}:${strPort}";
        wantedBy = [ "timers.target" ];
        timerConfig = {
          OnUnitInactiveSec = interval;
          OnBootSec = interval;
          RandomizedDelaySec = "30s";
        };
      };
      services.${name} = {
        description = "Remote disk unlock for ${host}:${strPort}";
        script = ''
          echo "Probing host ${host} port ${strPort} for disk unlock"
          if timeout 5 ${pkgs.bash}/bin/bash -c "</dev/tcp/${host}/${strPort}"; then
            echo "Host ${host} is listening on port ${strPort}, unlocking..."
            cat ${passwordFile} | \
              ${pkgs.openssh}/bin/ssh -oStrictHostKeyChecking=no -oUserKnownHostsFile=/dev/null \
                -i ${identityFile} -p ${strPort} ${host} || true
          else
            echo "No response on port ${strPort} from host ${host}"
          fi
        '';
      };
    };
  mkRemoteDiskUnlockers = cfgs: foldl' recursiveUpdate { } (map mkRemoteDiskUnlock cfgs);
in
{
  options.services.remote-unlock =
    with lib;
    mkOption {
      default = [ ];
      type = listOf (submodule {
        options = {
          enable = mkEnableOption "remote unlock";
          host = mkOption {
            type = str;
            description = "Host to connect to";
          };
          port = mkOption {
            type = port;
            description = "Port to connect to";
          };
          passwordFile = mkOption {
            type = str;
            description = "File containing the password to unlock the disk";
          };
          identityFile = mkOption {
            type = str;
            description = "File containing the identity to connect to the host";
          };
          interval = mkOption {
            type = str;
            description = "Interval to run the unlocker";
            default = "5m";
          };
        };
      });
    };

  config = mkIf ((length enabledCfgs) > 0) {
    systemd = mkRemoteDiskUnlockers enabledCfgs;
  };
}
