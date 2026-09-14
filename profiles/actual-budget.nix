{
  config,
  pkgs,
  ...
}:
let
  port = 5006;
in
{
  age.secrets = {
    restic-env.file = ../secrets/restic-env.age;
    restic-pw.file = ../secrets/restic-password.age;
  };

  services.restic.backups.actual-budget = {
    paths = [ "/var/lib/private/actual" ];
    environmentFile = config.age.secrets.restic-env.path;
    passwordFile = config.age.secrets.restic-pw.path;
    repository = "s3:http://storage01:3900/computer-backups";
    initialize = true;
    timerConfig = {
      OnCalendar = "02:30";
      Persistent = true;
      RandomizedDelaySec = "15m";
    };
    extraBackupArgs = [ "--tag=actual-budget" ];
    backupPrepareCommand = ''
      #!${pkgs.runtimeShell}
      ${pkgs.systemd}/bin/systemctl stop actual.service
    '';
    backupCleanupCommand = ''
      #!${pkgs.runtimeShell}
      ${pkgs.systemd}/bin/systemctl start actual.service
    '';
  };

  services.restic.backups.actual-budget-prune = {
    environmentFile = config.age.secrets.restic-env.path;
    passwordFile = config.age.secrets.restic-pw.path;
    repository = "s3:http://storage01:3900/computer-backups";
    timerConfig = {
      OnCalendar = "Sun *-*-* 03:30:00";
      Persistent = true;
      RandomizedDelaySec = "15m";
    };
    pruneOpts = [
      "--host=${config.networking.hostName}"
      "--tag=actual-budget"
      "--keep-daily=14"
      "--keep-weekly=8"
      "--keep-monthly=12"
    ];
    createWrapper = false;
  };

  services.actual = {
    enable = true;
    openFirewall = false;
    settings = {
      hostname = "127.0.0.1";
      inherit port;
      loginMethod = "password";
      allowedLoginMethods = [ "password" ];
      trustedProxies = [
        "127.0.0.1/32"
        "::1/128"
      ];
    };
  };

  services.tailscale.serve = {
    enable = true;
    services.budget.endpoints."tcp:443" = "http://127.0.0.1:${toString port}";
  };
}
