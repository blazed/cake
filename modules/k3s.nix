{
  lib,
  config,
  pkgs,
  ...
}: let
  inherit (lib) mkOption mkIf mkMerge mkForce types optionals mapAttrsToList flatten;
  inherit (builtins) concatStringsSep isList isString isPath isAttrs isBool mapAttrs sort lessThan;
  cfg = config.services.k3s;
  k3sManifestsDir = "/var/lib/rancher/k3s/server/manifests";
  settingsToCli = s: let
    boolToCli = path: value:
      if value
      then "--${path}"
      else "";
    listToCli = path: value:
      concatStringsSep " "
      (map (item: "--${path} \"${toString item}\"") value);
    attrsToCli = path:
      mapAttrsToList (
        k: v:
          if isBool v
          then boolToCli path v
          else "--${path} \"${k}=${toString v}\""
      );
    fieldToCli = path: value:
      if isAttrs value
      then attrsToCli path value
      else if isBool value
      then boolToCli path value
      else if isList value
      then listToCli path value
      else "--${path} \"${toString value}\"";
  in
    flatten (mapAttrsToList fieldToCli s);
in {
  options.services.k3s.autoDeploy = mkOption {
    type = types.attrsOf (
      types.either
      types.path
      (types.attrsOf types.anything)
    );
    default = {};
    apply = mapAttrs (name: value:
      if (isPath value || isString value)
      then value
      else
        pkgs.runCommand "${name}.yaml" {} ''
          cat<<EOF>$out
          ${builtins.toJSON value}
          EOF
        '');
  };

  options.services.k3s.after = mkOption {
    type = types.listOf types.str;
    default = [];
  };

  options.services.k3s.disable = mkOption {
    type = types.listOf (types.enum ["coredns" "servicelb" "traefik" "local-storage" "metrics-server"]);
    default = [];
  };

  options.services.k3s.settings = mkOption {
    type = types.attrsOf types.anything;
    default = {};
  };

  config = mkIf cfg.enable {
    assertions = mkForce [];
    services.k3s.extraFlags = concatStringsSep " " (sort lessThan (settingsToCli cfg.settings));
    systemd.services.k3s.preStart = mkIf (cfg.role == "server") ''
      mkdir -p ${k3sManifestsDir}
      ${
        concatStringsSep "\n" (mapAttrsToList (
            name: path: "cp ${path} ${k3sManifestsDir}/${name}.yaml"
          )
          cfg.autoDeploy)
      }
      ${
        concatStringsSep "\n" (map (
            manifestName: "touch ${k3sManifestsDir}/${manifestName}.yaml.skip"
          )
          cfg.disable)
      }
    '';
    ## Random fixes and hacks for k3s networking
    ## see: https://github.com/NixOS/nixpkgs/issues/98766
    boot.kernelModules = ["br_netfilter" "ip_conntrack" "ip_vs" "ip_vs_rr" "ip_vs_wrr" "ip_vs_sh" "overlay"];
    systemd.services.k3s.after = ["network-online.service" "firewall.service"] ++ cfg.after;
  };
}
