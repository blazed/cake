{ adminUser, ... }:
{
  age.secrets = {
    restic-env = {
      file = ../secrets/restic-env.age;
      owner = "1447";
    };
    restic-pw = {
      file = ../secrets/restic-password.age;
      owner = "1447";
    };
  };

  services.restic = {
    backups = {
      remote = {
        paths = [
          "/home/${adminUser.name}/.factorio"
          "/home/${adminUser.name}/Documents"
          "/home/${adminUser.name}/Faugus/battlenet/drive_c/Program Files (x86)/World of Warcraft/_retail_/Interface"
          "/home/${adminUser.name}/Faugus/battlenet/drive_c/Program Files (x86)/World of Warcraft/_retail_/WTF"
          "/home/${adminUser.name}/Photos"
          "/home/${adminUser.name}/Pictures"
          "/home/${adminUser.name}/code"
        ];
        environmentFile = "/run/agenix/restic-env";
        passwordFile = "/run/agenix/restic-pw";
        repository = "s3:http://storage01:3900/computer-backups";
        initialize = true;
        timerConfig.OnCalendar = "00/2:00";
        timerConfig.RandomizedDelaySec = "30m";
        extraBackupArgs = [
          "--exclude=\".devenv\""
          "--exclude=\".direnv\""
          "--exclude=\".mypy_cache\""
          "--exclude=\".pnpm-store\""
          "--exclude=\".pytest_cache\""
          "--exclude=\".ruff_cache\""
          "--exclude=\".terraform\""
          "--exclude=\".tox\""
          "--exclude=\".venv\""
          "--exclude=\"__pycache__\""
          "--exclude=\"go/pkg/mod\""
          "--exclude=\"node_modules/*\""
          "--exclude=\"result\""
          "--exclude=\"target\""
        ];
      };
    };
  };
}
