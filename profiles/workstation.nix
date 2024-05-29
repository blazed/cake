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
    "net.ipv6.conf.all.disable_ipv6" = 1;
    "net.ipv6.conf.default.disable_ipv6" = 1;
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
  programs.steam.enable = true;

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

  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    wireplumber = {
      enable = true;
      configPackages = [
        (pkgs.writeTextDir "share/wireplumber/bluetooth.lua.d/51-bluez-config.lua" ''
          bluez_monitor.properties = {
            ["bluez5.enable-sbc-xq"] = true,
            ["bluez5.enable-msbc"] = true,
            ["bluez5.enable-hw-volume"] = true,
            ["bluez5.headset-roles"] = "[ hsp_hs hsp_ag hfp_hf hfp_ag ]"
          }
        '')
      ];
    };
  };

  xdg.portal = {
    enable = true;
    wlr.enable = true;
    extraPortals = [pkgs.xdg-desktop-portal-gtk];
    config = let
      wlrConf = {
        default = ["wlr" "gtk"];
        "org.freedesktop.impl.portal.Secret" = ["gnome-keyring"];
      };
    in {
      common = {
        default = ["gtk"];
        "org.freedesktop.impl.portal.Secret" = ["gnome-keyring"];
      };
      sway = wlrConf;
    };
  };

  fonts.packages = with pkgs; [
    google-fonts
    font-awesome_5
    powerline-fonts
    roboto
    (pkgs.nerdfonts.override {
      fonts = ["JetBrainsMono" "DroidSansMono" "Iosevka" "IosevkaTerm" "RobotoMono"];
    })
  ];

  machinePurpose = "workstation";
}
