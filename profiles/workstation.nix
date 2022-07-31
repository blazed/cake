{
  config,
  pkgs,
  lib,
  inputs,
  ...
}: let
  inherit (lib) mapAttrs' nameValuePair filterAttrs;
  inherit (builtins) toString;
  inherit (config.users) users;
in {
  imports = [
    ./defaults.nix
    inputs.nixos-hardware.nixosModules.common-pc-ssd
  ];

  boot.kernel.sysctl = {
    "fs.inotify.max_user_watches" = 12288;
  };

  hardware.opengl.enable = true;
  hardware.opengl.driSupport = true;

  sound.enable = false;
  security.rtkit.enable = true;

  environment.pathsToLink = ["/etc/gconf"];

  powerManagement.enable = true;
  powerManagement.powertop.enable = true;

  virtualisation.docker.enable = true;

  programs.ssh.startAgent = true;
  programs.dconf.enable = true;

  services.gvfs.enable = true;
  services.gnome.sushi.enable = true;
  services.openssh.enable = true;

  services.fwupd.enable = true;

  services.dbus.packages = with pkgs; [gcr dconf gnome3.sushi];
  services.udev.packages = with pkgs; [gnome3.gnome-settings-daemon];
  services.udev.extraRules = ''
    ## ledger
    SUBSYSTEMS=="usb", ATTRS{idVendor}=="2c97", ATTRS{idProduct}=="0005|5000|5001|5002|5003|5004|5005|5006|5007|5008|5009|500a|500b|500c|500d|500e|500f|5010|5011|5012|5013|5014|5015|5016|5017|5018|5019|501a|501b|501c|501d|501e|501f", TAG+="uaccess", TAG+="udev-acl", OWNER="blazed"
  '';

  environment.etc."systemd/sleep.conf".text = "HibernateDelaySec=8h";

  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    media-session.config.bluez-monitor.rules = [
      {
        # Matches all cards
        matches = [{"device.name" = "~bluez_card.*";}];
        actions = {
          "update-props" = {
            "bluez5.auto-connect" = ["hfp_hf" "hsp_hs" "a2dp_sink"];
            "bluez5.reconnect-profiles" = ["hfp_hf" "hsp_hs" "a2dp_sink"];
            # mSBC is not expected to work on all headset + adapter combinations.
            "bluez5.msbc-support" = true;
            # SBC-XQ is not expected to work on all headset + adapter combinations.
            "bluez5.sbc-xq-support" = true;
          };
        };
      }
      {
        matches = [
          # Matches all sources
          {"node.name" = "~bluez_input.*";}
          # Matches all outputs
          {"node.name" = "~bluez_output.*";}
        ];
        actions = {
          "node.pause-on-idle" = false;
        };
      }
    ];
  };

  xdg.portal.enable = true;
  xdg.portal.extraPortals = [pkgs.xdg-desktop-portal-wlr pkgs.xdg-desktop-portal-gtk];

  environment.systemPackages = [
    pkgs.gitAndTools.hub
    pkgs.go_1_18
    pkgs.discord
    pkgs.signal-desktop
    pkgs.tdesktop ## Telegrom
    pkgs.lm_sensors
    pkgs.firefox-devedition-bin
    pkgs.lutris
    pkgs.ledger-live-desktop
  ];

  programs.steam.enable = true;

  environment.state."/keep" = {
    users = mapAttrs' (
      userName: conf:
        nameValuePair (toString conf.uid) {
          directories = [
            "/home/${userName}/Downloads"
            "/home/${userName}/Documents"
            "/home/${userName}/Photos"
            "/home/${userName}/Pictures"
            "/home/${userName}/.local/share/direnv"
            "/home/${userName}/.local/share/fish"
            "/home/${userName}/.local/share/containers"
            "/home/${userName}/.local/share/Steam"
            "/home/${userName}/.local/share/TelegramDesktop"
            "/home/${userName}/.mail"
            "/home/${userName}/.cache/mu"
            "/home/${userName}/.cache/nix"
            "/home/${userName}/.cache/nix-index"
            "/home/${userName}/.cache/vim"
            "/home/${userName}/.cache/rbw"
            "/home/${userName}/.mozilla"
            "/home/${userName}/.gnupg"
            "/home/${userName}/.config/gcloud"
            "/home/${userName}/.config/discord"
            "/home/${userName}/.config/pulse"
            "/home/${userName}/.config/Signal"
            "/home/${userName}/.config/spotify"
            # "/home/${userName}/.config/Ledger Live"
            "/home/${userName}/.backup/undo"
            "/home/${userName}/.local/state/pipewire/media-session.d"
            "/home/${userName}/.local/state/wireplumber"
            "/home/${userName}/.terraform.d"
            "/home/${userName}/code"
          ];

          files = [
            "/home/${userName}/.kube/config"
            "/home/${userName}/.ssh/known_hosts"
            "/home/${userName}/.config/gopass/config.yml"
          ];
        }
    ) (filterAttrs (_: user: user.isNormalUser) users);
  };

  fonts.fonts = with pkgs; [
    google-fonts
    font-awesome_5
    powerline-fonts
    roboto
  ];
}
