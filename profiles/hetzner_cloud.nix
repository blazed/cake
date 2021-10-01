{ modulesPath, ... }:
{
  imports = [
    (modulesPath + "/profiles/qemu-guest.nix")
  ];

  boot = {
    loader.grub.enable = true;
    loader.grub.version = 2;
    loader.grub.devices = [ "/dev/sda" ];

    initrd.availableKernelModules =
      [ "ahci" "xhci_pci" "virtio_pci" "sd_mod" "sr_mod" ];
  };
}
