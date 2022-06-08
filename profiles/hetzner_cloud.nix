{
  modulesPath,
  lib,
  ...
}: let
  inherit (lib) mkForce;
in {
  imports = [
    (modulesPath + "/profiles/qemu-guest.nix")
  ];

  boot = {
    loader.systemd-boot.enable = mkForce false;
    loader.grub.enable = true;
    loader.grub.version = 2;
    loader.grub.devices = ["/dev/sda"];

    initrd.availableKernelModules = ["ahci" "xhci_pci" "virtio_pci" "sd_mod" "sr_mod"];
  };
}
