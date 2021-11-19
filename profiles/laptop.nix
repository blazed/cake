{ lib, pkgs, ... }:
{
  imports = [
    ./workstation.nix
    ./wifi.nix
  ];

  services.logind.lidSwitch = "suspend-then-hibernate";
  services.disable-usb-wakeup.enable = true;
  programs.light.enable = true;
  services.upower.enable = true;

  boot.kernel.sysctl = {
    "vm.dirty_writeback_centisecs" = lib.mkDefault 1500;
    "vm.laptop_mode" = lib.mkDefault 5;
    # "vm.swappiness" = lib.mkDefault 1;
  };

  hardware.opengl.extraPackages = [
    pkgs.intel-media-driver
    pkgs.vaapiIntel
    pkgs.vaapiVdpau
    pkgs.libvdpau-va-gl
  ];
}
