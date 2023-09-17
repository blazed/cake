{
  pkgs,
  lib,
  inputs,
  ...
}: let
  runViaSystemdCat = {
    name,
    cmd,
  }:
    pkgs.writeShellApplication {
      inherit name;
      text = ''
        exec ${pkgs.udev}/bin/systemd-cat --identifier=${name} ${cmd}
      '';
    };

    runViaShell = {
      env? {},
      sourceHmVars ? true,
      viaSystemdCat ? true,
      name,
      cmd,
    }:
      pkgs.writeShellApplication {
        inherit name;
        text = ''
          ${lib.concatStringsSep "\n" (lib.mapAttrsToList (k: v: "export ${k}=\"${v}\"") env)}
          ${
            if sourceHmVars
            then ''
              if [ -e /etc/profiles/per-user/"$USER"/etc/profile.d/hm-session-vars.sh ]; then
                set +u
                # shellcheck disable=SC1090
                source /etc/profiles/per-user/"$USER"/etc/profile.d/hm-session-vars.sh
                set -u
              fi
            ''
            else ""
          }
          ${
            if viaSystemdCat
            then ''
              exec ${runViaSystemdCat {inherit name cmd;}}/bin/${name}
            ''
            else ''
              exec ${cmd}
            ''
          }
        '';
      };

  runSway = runViaShell {
    env = {
      XDG_SESSION_TYPE = "wayland";
      XDG_CURRENT_DESKTOP = "sway";
      XDG_SESSION_DESKTOP = "sway";
    };
    name = "sway";
    cmd = "${pkgs.sway}/bin/sway";
  };

  runHyprland = runViaShell {
    env = {
      XDG_SESSION_TYPE = "wayland";
      XDG_CURRENT_DESKTOP = "Hyprland";
      XDG_SESSION_DESKTOP = "Hyprland";
    };
    name = "Hyprland";
    cmd = "${pkgs.hyprland}/bin/Hyprland";
  };

  desktopSession = name: command:
    pkgs.writeText "${name}.desktop" ''
      [Desktop Entry]
      Type=Application
      Name=${name}
      Exec=${command}
    '';

  sessions = [
    {
      name = "sway.desktop";
      path = desktopSession "sway" "${runSway}/bin/sway";
    }
    {
      name = "Hyprland.desktop";
      path = desktopSession "Hyprland" "${runHyprland}/bin/Hyprland";
    }
  ];

  createGreeter = default: sessions: let
    sessionDir = pkgs.linkFarm "sessions" (
      builtins.filter (item: item.name != "${default}.desktop") sessions
    );
  in
    pkgs.writeShellApplication {
      name = "greeter";
      runtimeInputs = [runSway runHyprland pkgs.systemd pkgs.greetd.tuigreet];
      text = ''
        tuigreet --sessions ${sessionDir} --time -r --remember-session --power-shutdown 'systemctl poweroff' --power-reboot 'systemctl reboot' --cmd ${default}
      '';
    };
in {
  services.greetd = {
    enable = true;
    restart = true;
    settings = {
      default_session.command = "${createGreeter "Hyprland" sessions}/bin/greeter";
    };
  };
  systemd.services.greetd.serviceConfig = {
    ExecPreStart = "${pkgs.util-linux}/bin/kill -SIGRTMIN+21 1";
    ExecStopPost = "${pkgs.util-linux}/bin/kill -SIGRTMIN+20 1";
  };
}
