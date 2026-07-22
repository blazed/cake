{
  adminUser,
  config,
  inputs,
  lib,
  pkgs,
  ...
}:
let
  runViaSystemdCat =
    {
      name,
      cmd,
      systemdSession,
    }:
    pkgs.writeShellApplication {
      inherit name;
      text = ''
        trap 'systemctl --user stop ${systemdSession} || true' EXIT
        exec ${pkgs.systemd}/bin/systemd-cat --identifier=${name} ${cmd}
      '';
    };

  runViaShell =
    {
      env ? { },
      sourceHmVars ? true,
      viaSystemdCat ? true,
      name,
      cmd,
    }:
    pkgs.writeShellApplication {
      inherit name;
      text = ''
        ${lib.concatStringsSep "\n" (lib.mapAttrsToList (key: value: "export ${key}=\"${value}\"") env)}
        ${
          if sourceHmVars then
            ''
              if [ -e /etc/profiles/per-user/"$USER"/etc/profile.d/hm-session-vars.sh ]; then
                set +u
                # shellcheck disable=SC1090
                source /etc/profiles/per-user/"$USER"/etc/profile.d/hm-session-vars.sh
                set -u
              fi
            ''
          else
            ""
        }
        ${
          if viaSystemdCat then
            ''
              exec ${
                runViaSystemdCat {
                  inherit name cmd;
                  systemdSession = "${lib.toLower name}-session.target";
                }
              }/bin/${name}
            ''
          else
            ''
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

  runNiri = runViaShell {
    env = {
      XDG_SESSION_TYPE = "wayland";
      XDG_CURRENT_DESKTOP = "niri";
      XDG_SESSION_DESKTOP = "niri";
    };
    name = "niri";
    cmd = "${config.programs.niri.package}/bin/niri-session";
  };

  desktopSession =
    name: command:
    pkgs.writeText "${name}.desktop" ''
      [Desktop Entry]
      Type=Application
      Name=${name}
      Exec=${command}
    '';

  sessions =
    pkgs.runCommand "cake-wayland-sessions"
      {
        passthru.providedSessions = [
          "sway"
          "niri"
          "nushell"
          "bash"
        ];
      }
      ''
        mkdir -p "$out/share/wayland-sessions"
        ln -s ${desktopSession "sway" "${runSway}/bin/sway"} "$out/share/wayland-sessions/sway.desktop"
        ln -s ${desktopSession "niri" "${runNiri}/bin/niri"} "$out/share/wayland-sessions/niri.desktop"
        ln -s ${desktopSession "nushell" "${pkgs.nushell}/bin/nu"} "$out/share/wayland-sessions/nushell.desktop"
        ln -s ${desktopSession "bash" "${pkgs.bashInteractive}/bin/bash"} "$out/share/wayland-sessions/bash.desktop"
      '';

  greeterCompositor =
    {
      sway = "sway";
      niri = "niri";
    }
    .${config.greeter.defaultSession};

  defaultSessionDesktopId = "${config.greeter.defaultSession}.desktop";
  greeterCacheDir = "/var/lib/dms-greeter";

  greeterConfig = {
    sway = ''
      input * {
        xkb_layout us
        xkb_variant dvp
        xkb_options compose:ralt,caps:escape
      }

      output "LG Electronics 27GL850 007NTWG5A929" {
        mode 2560x1440@144.000Hz
        pos 0 0
      }
      output "ASUSTek COMPUTER INC PG279QE #ASMJ3N131Wnd" {
        mode 2560x1440@143.998Hz
        pos 2560 0
      }
      output "LG Electronics 27GL850 007NTUW8L254" {
        mode 2560x1440@144.000Hz
        pos 5120 0
      }
    '';
    niri = ''
      input {
        keyboard {
          xkb {
            layout "us"
            variant "dvp"
            options "compose:ralt,caps:escape"
          }
        }
      }
    '';
  };
in
{
  imports = [ inputs.dank-greeter.nixosModules.default ];

  options.greeter.defaultSession = lib.mkOption {
    type = lib.types.enum [
      "sway"
      "niri"
    ];
    default = "sway";
    description = "Default desktop session and compositor used to render DMS Greeter.";
  };

  config = {
    programs.dms-greeter = {
      enable = true;
      package = inputs.dank-greeter.packages.${pkgs.stdenv.hostPlatform.system}.default;
      compositor.name = greeterCompositor;
      compositor.customConfig = greeterConfig.${greeterCompositor};
      configHome = "/home/${adminUser.name}";
    };

    services.displayManager = {
      defaultSession = config.greeter.defaultSession;
      sessionPackages = [ sessions ];
    };
    services.greetd.restart = true;

    systemd.services.greetd = {
      preStart = lib.mkAfter ''
        memory_dir=${greeterCacheDir}/.local/state
        memory_file="$memory_dir/memory.json"
        memory_tmp="$memory_dir/memory.json.tmp"

        install -d -m 0750 -o greeter -g greeter "$memory_dir"
        if [ -f "$memory_file" ]; then
          ${lib.getExe pkgs.jq} --arg session ${lib.escapeShellArg defaultSessionDesktopId} \
            '.lastSessionDesktopId = $session | del(.lastSessionId, .lastSessionExec)' \
            "$memory_file" > "$memory_tmp"
        else
          ${lib.getExe pkgs.jq} -n --arg session ${lib.escapeShellArg defaultSessionDesktopId} \
            '{ lastSessionDesktopId: $session }' > "$memory_tmp"
        fi
        install -m 0640 -o greeter -g greeter "$memory_tmp" "$memory_file"
        rm -f "$memory_tmp"
      '';

      serviceConfig = {
        ExecStartPre = "${pkgs.util-linux}/bin/kill -SIGRTMIN+21 1";
        ExecStopPost = "${pkgs.util-linux}/bin/kill -SIGRTMIN+20 1";
      };
    };
  };
}
