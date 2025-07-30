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
          "/home/${adminUser.name}/Documents"
          "/home/${adminUser.name}/Photos"
          "/home/${adminUser.name}/Pictures"
          "/home/${adminUser.name}/code"
          "/home/${adminUser.name}/.factorio"
          "/home/${adminUser.name}/.var/app/com.usebottles.bottles/data/bottles/bottles/Games/drive_c/Program Files (x86)/World of Warcraft/_retail_/Interface"
          "/home/${adminUser.name}/.var/app/com.usebottles.bottles/data/bottles/bottles/Games/drive_c/Program Files (x86)/World of Warcraft/_retail_/WTF"
        ];
        environmentFile = "/run/agenix/restic-env";
        passwordFile = "/run/agenix/restic-pw";
        repository = "s3:http://storage01:9000/computer-backups";
        initialize = true;
        timerConfig.OnCalendar = "00/2:00";
        timerConfig.RandomizedDelaySec = "30m";
        extraBackupArgs = [
          "--exclude=\".direnv\""
          "--exclude=\".terraform\""
          "--exclude=\"node_modules/*\""
        ];
      };
    };
  };
}
