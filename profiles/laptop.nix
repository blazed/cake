{
  lib,
  pkgs,
  ...
}:
{
  imports = [
    ./workstation.nix
    ./wifi.nix
  ];

  services.logind.lidSwitch = "suspend-then-hibernate";
  services.disable-usb-wakeup.enable = true;
  programs.light.enable = true;
  services.upower.enable = true;

  powerManagement.enable = true;
  powerManagement.powertop.enable = true;

  boot.kernel.sysctl = {
    "vm.dirty_writeback_centisecs" = lib.mkDefault 1500;
    "vm.laptop_mode" = lib.mkDefault 5;
    # "vm.swappiness" = lib.mkDefault 1;
  };

  security.pam.services.swaylock = {
    text = ''
      auth include login
    '';
  };

  hardware.graphics.extraPackages = [
    pkgs.intel-media-driver
    pkgs.intel-vaapi-driver
    pkgs.libva-vdpau-driver
    pkgs.libvdpau-va-gl
  ];
}
