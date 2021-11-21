{ config, pkgs, lib, inputs, ... }:
let
  inherit (lib) mapAttrs' nameValuePair filterAttrs;
  inherit (builtins) toString;
  users = config.users.users;
in
{
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

  environment.pathsToLink = [ "/etc/gconf" ];

  powerManagement.enable = true;
  powerManagement.powertop.enable = true;

  virtualisation.docker.enable = false;
  virtualisation.podman.enable = true;
  virtualisation.podman.dockerCompat = true;

  programs.ssh.startAgent = true;
  programs.dconf.enable = true;

  services.gvfs.enable = true;
  services.gnome.sushi.enable = true;
  services.openssh.enable = true;

  services.fwupd.enable = true;

  services.dbus.packages = with pkgs; [ gcr dconf gnome3.sushi ];
  services.udev.packages = with pkgs; [ gnome3.gnome-settings-daemon ];

  environment.etc."systemd/sleep.conf".text = "HibernateDelaySec=8h";

  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  xdg.portal.enable = true;
  xdg.portal.gtkUsePortal = true;
  xdg.portal.extraPortals = [ pkgs.xdg-desktop-portal-wlr pkgs.xdg-desktop-portal-gtk ];

  environment.systemPackages = [
    pkgs.gitAndTools.hub
    pkgs.go
    pkgs.discord
    pkgs.signal-desktop
    pkgs.tdesktop ## Telegrom
    pkgs.lm_sensors
    pkgs.firefox-devedition-bin
  ];

  environment.state."/keep" = {
    users = mapAttrs' (userName: conf:
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
          "/home/${userName}/.mozilla"
          "/home/${userName}/.gnupg"
          "/home/${userName}/.config/gcloud"
          "/home/${userName}/.config/discord"
          "/home/${userName}/.config/pulse"
          "/home/${userName}/.config/Signal"
          "/home/${userName}/.config/spotify"
          "/home/${userName}/.backup/undo"
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
