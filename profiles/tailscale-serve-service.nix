{
  config,
  lib,
  pkgs,
  name,
  target,
  upstreamUnits,
}:
let
  serve = "${lib.getExe' pkgs.util-linux "flock"} /run/tailscale-serve.lock ${lib.getExe config.services.tailscale.package} serve --service=svc:${name} --https=443";
in
{
  description = "Expose ${name} as a Tailscale Service";
  after = [
    "tailscaled.service"
    "tailscale-auth.service"
  ]
  ++ upstreamUnits;
  wants = [ "tailscaled.service" ] ++ upstreamUnits;
  wantedBy = [ "multi-user.target" ];
  serviceConfig = {
    Type = "oneshot";
    RemainAfterExit = true;
    ExecStart = "${serve} --yes ${target}";
    ExecStop = "${serve} off";
  };
}
