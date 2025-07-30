{ inputs, ... }:
{
  imports = [
    inputs.nixos-hardware.nixosModules.framework-13-7040-amd
  ];

  boot.initrd.availableKernelModules = [
    "nvme"
    "xhci_pci"
    "thunderbolt"
    "usb_storage"
    "sd_mod"
  ];
  services.fprintd.enable = true;

  environment.persistence."/keep" = {
    directories = [ "/var/lib/fprint" ];
  };
}
