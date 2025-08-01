{
  adminUser,
  config,
  pkgs,
  inputs,
  ...
}:
{
  imports = [
    ./defaults.nix
    inputs.nixos-hardware.nixosModules.common-pc-ssd
  ];

  boot.kernel.sysctl = {
    "fs.inotify.max_user_watches" = 12288;
    "net.ipv6.conf.all.disable_ipv6" = 1;
    "net.ipv6.conf.default.disable_ipv6" = 1;
  };

  hardware.graphics.enable = true;
  hardware.graphics.enable32Bit = true;

  hardware.graphics.extraPackages = [
    pkgs.intel-media-driver
    pkgs.vaapiIntel
    pkgs.vaapiVdpau
    pkgs.libvdpau-va-gl
    pkgs.rocmPackages.clr
    pkgs.rocmPackages.clr.icd
    pkgs.amdvlk
  ];

  hardware.graphics.extraPackages32 = [
    pkgs.intel-media-driver
    pkgs.vaapiIntel
    pkgs.vaapiVdpau
    pkgs.libvdpau-va-gl
    pkgs.amdvlk
  ];

  security.rtkit.enable = true;
  hardware.bluetooth.enable = true;
  networking.wireless.iwd.enable = true;

  environment.pathsToLink = [ "/etc/gconf" ];

  security.pam.services.swaylock = {
    text = ''
      auth include login
    '';
  };
  security.pam.services.hyprlock = { };
  security.pam.services.hyprland.enableGnomeKeyring = true;

  powerManagement.enable = true;
  powerManagement.powertop.enable = true;

  environment.persistence."/keep".directories = [ "/var/cache/powertop" ];

  virtualisation.docker.enable = true;
  virtualisation.podman.enable = false;
  virtualisation.podman.dockerCompat = false;

  programs.ssh.startAgent = true;
  services.gnome.gcr-ssh-agent.enable = false;

  services.pcscd.enable = true;

  programs.dconf.enable = true;

  services.gvfs.enable = true;
  services.gnome.sushi.enable = true;
  services.openssh.enable = true;

  services.fwupd.enable = true;

  services.dbus.packages = with pkgs; [
    gcr
    dconf
    sushi
  ];
  services.udev.packages = with pkgs; [ gnome-settings-daemon ];
  services.udev.extraRules = ''
    ## ledger
    SUBSYSTEMS=="usb", ATTRS{idVendor}=="2c97", ATTRS{idProduct}=="0005|5000|5001|5002|5003|5004|5005|5006|5007|5008|5009|500a|500b|500c|500d|500e|500f|5010|5011|5012|5013|5014|5015|5016|5017|5018|5019|501a|501b|501c|501d|501e|501f", TAG+="uaccess", TAG+="udev-acl", OWNER="blazed"
  '';

  environment.etc."systemd/sleep.conf".text = "HibernateDelaySec=8h";

  services.write-iwd-secrets.enable = true;

  services.gnome.gnome-keyring.enable = true;

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
    extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
    config =
      let
        wlrConf = {
          default = [
            "wlr"
            "gtk"
          ];
          "org.freedesktop.impl.portal.Secret" = [ "gnome-keyring" ];
        };
      in
      {
        common = {
          default = [ "gtk" ];
          "org.freedesktop.impl.portal.Secret" = [ "gnome-keyring" ];
        };
        sway = wlrConf;
      };
  };

  fonts.packages = with pkgs; [
    google-fonts
    font-awesome_5
    powerline-fonts
    roboto
    nerd-fonts.jetbrains-mono
    nerd-fonts.droid-sans-mono
    nerd-fonts.iosevka
    nerd-fonts.iosevka-term
    nerd-fonts.roboto-mono
  ];

  fileSystems."/home/${adminUser.name}/Documents/nfs/blazed" = {
    device = "storage01.tailef5cf.ts.net:/volume1/blazed";
    fsType = "nfs";
    options = [
      "x-systemd.automount"
      "noauto"
      "x-systemd.idle-timeout=600"
    ];
  };

  machinePurpose = "workstation";
}
