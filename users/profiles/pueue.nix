{ pkgs, ...}: {
  systemd.user.services.pueue = {
    Unit.Description = "Pueue daemon";
    Service = {
      Restart = "no";
      ExecStart = "${pkgs.pueue}/bin/pueued -vv";
    };
    Install.WantedBy = [ "default.target" ];
  };

}
