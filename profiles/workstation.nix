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
  hardware.opengl.driSupport32Bit = true;
  hardware.opengl.extraPackages = [
    pkgs.intel-media-driver
    pkgs.vaapiIntel
    pkgs.vaapiVdpau
    pkgs.libvdpau-va-gl
    pkgs.rocm-opencl-icd
    pkgs.rocm-opencl-runtime
    pkgs.amdvlk
  ];

  sound.enable = false;
  security.rtkit.enable = true;

  security.pam.services.swaylock = {
    text = ''
      auth include login
    '';
  };
  environment.pathsToLink = ["/etc/gconf"];

  virtualisation.docker.enable = true;

  programs.ssh.startAgent = true;
  programs.dconf.enable = true;

  services.gvfs.enable = true;
  services.gnome.sushi.enable = true;
  services.openssh.enable = true;

  services.fwupd.enable = true;

  services.flatpak.enable = true;

  services.dbus.packages = with pkgs; [gcr dconf gnome.sushi];
  services.udev.packages = with pkgs; [gnome.gnome-settings-daemon];
  services.udev.extraRules = ''
    ## ledger
    SUBSYSTEMS=="usb", ATTRS{idVendor}=="2c97", ATTRS{idProduct}=="0005|5000|5001|5002|5003|5004|5005|5006|5007|5008|5009|500a|500b|500c|500d|500e|500f|5010|5011|5012|5013|5014|5015|5016|5017|5018|5019|501a|501b|501c|501d|501e|501f", TAG+="uaccess", TAG+="udev-acl", OWNER="blazed"
  '';

  environment.etc."systemd/sleep.conf".text = "HibernateDelaySec=8h";

  environment.etc = {
    "wireplumber/bluetooth.lua.d/51-bluez-config.lua".text = ''
        bluez_monitor.properties = {
            ["bluez5.enable-sbc-xq"] = true,
            ["bluez5.enable-msbc"] = true,
            ["bluez5.enable-hw-volume"] = true,
            ["bluez5.headset-roles"] = "[ hsp_hs hsp_ag hfp_hf hfp_ag ]"
        }
    '';
  };

  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    wireplumber.enable = true;
  };

  xdg.portal.enable = true;
  xdg.portal.extraPortals = [pkgs.xdg-desktop-portal-wlr pkgs.xdg-desktop-portal-gtk];

  environment.systemPackages = [
    pkgs.discord
    pkgs.entr
    pkgs.firefox-devedition-bin
    pkgs.go_1_20
    pkgs.ledger-live-desktop
    pkgs.monero-gui
    pkgs.monero-cli
    pkgs.lm_sensors
    pkgs.lutris
    pkgs.signal-desktop
    pkgs.tdesktop ## Telegram
    pkgs.vulkan-loader
    pkgs.insomnia
  ];

  programs.steam.enable = true;

  environment.state."/keep" = {
    directories = [
      "/var/lib/flatpak"
    ];
    users = mapAttrs' (
      userName: conf:
        nameValuePair (toString conf.uid) {
          directories = [
            "/home/${userName}/.backup/undo"
            "/home/${userName}/.cache/mu"
            "/home/${userName}/.cache/nix"
            "/home/${userName}/.cache/nix-index"
            "/home/${userName}/.cache/rbw"
            "/home/${userName}/.cache/vim"
            "/home/${userName}/.cacke/monero-project"
            "/home/${userName}/.config/Insomnia"
            "/home/${userName}/.config/Signal"
            "/home/${userName}/.config/WowUpCf"
            "/home/${userName}/.config/discord"
            "/home/${userName}/.config/easyeffects"
            "/home/${userName}/.config/gcloud"
            "/home/${userName}/.config/gh"
            "/home/${userName}/.config/github-copilot"
            "/home/${userName}/.config/lutris"
            "/home/${userName}/.config/monero-project"
            "/home/${userName}/.config/obs-studio"
            "/home/${userName}/.config/pipewire"
            "/home/${userName}/.config/pulse"
            "/home/${userName}/.config/spotify"
            "/home/${userName}/.config/warcraftlogs"
            "/home/${userName}/.factorio"
            "/home/${userName}/.gnupg"
            "/home/${userName}/.local/share/Steam"
            "/home/${userName}/.local/share/TelegramDesktop"
            "/home/${userName}/.local/share/containers"
            "/home/${userName}/.local/share/direnv"
            "/home/${userName}/.local/share/fish"
            "/home/${userName}/.local/share/flatpak"
            "/home/${userName}/.local/share/lutris"
            "/home/${userName}/.local/share/vulkan"
            "/home/${userName}/.local/state/pipewire/media-session.d"
            "/home/${userName}/.local/state/wireplumber"
            "/home/${userName}/.mail"
            "/home/${userName}/.mozilla"
            "/home/${userName}/.steam"
            "/home/${userName}/.terraform.d"
            "/home/${userName}/.var"
            "/home/${userName}/.wine"
            "/home/${userName}/Documents"
            "/home/${userName}/Downloads"
            "/home/${userName}/Games"
            "/home/${userName}/Photos"
            "/home/${userName}/Pictures"
            "/home/${userName}/code"
            # "/home/${userName}/.config/Ledger Live"
          ];

          files = [
            "/home/${userName}/.config/gopass/config.yml"
            "/home/${userName}/.kube/config"
            "/home/${userName}/.ssh/known_hosts"
          ];
        }
    ) (filterAttrs (_: user: user.isNormalUser) users);
  };

  fonts.packages = with pkgs; [
    google-fonts
    font-awesome_5
    powerline-fonts
    roboto
  ];

  machinePurpose = "workstation";
}
