{
  lib,
  config,
  ...
}:
let
  bcacheFsDevices = config.bcachefs.devices;
  tmpfsRootSizeGb = config.tmpfsRoot.sizegb;
in
{
  fileSystems."/" = {
    device = "none";
    fsType = "tmpfs";
    options = [
      "defaults"
      "size=${toString tmpfsRootSizeGb}G"
      "mode=755"
    ];
  };

  fileSystems."/keep" = {
    device = lib.concatStringsSep ":" bcacheFsDevices;
    fsType = "bcachefs";
    options = [
      "defaults"
      "compression=zstd"
      "background_compression=zstd"
    ];
    neededForBoot = true;
  };

  fileSystems."/nix" = {
    device = "/keep/nix";
    options = [ "bind" ];
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-label/boot";
    fsType = "vfat";
  };

  boot.initrd.supportedFilesystems = [
    "bcachefs"
    "vfat"
  ];

  swapDevices = [ { device = "/dev/disk/by-label/swap"; } ];

  boot.initrd.luks.devices =
    lib.recursiveUpdate
      {
        cryptkey.device = "/dev/disk/by-label/cryptkey";

        encrypted_root = {
          device = "/dev/disk/by-label/encrypted_root";
          keyFile = "/dev/mapper/cryptkey";
          bypassWorkqueues = true;
          allowDiscards = true;
        };

        encrypted_swap = {
          device = "/dev/disk/by-label/encrypted_swap";
          keyFile = "/dev/mapper/cryptkey";
          bypassWorkqueues = true;
          allowDiscards = true;
        };
      }
      (
        builtins.listToAttrs (
          lib.imap1 (idx: device: {
            name = "encrypted_root${toString idx}";
            value = {
              device = "/dev/disk/by-label/encrypted_root${toString idx}";
              keyFile = "/dev/mapper/cryptkey";
              bypassWorkqueues = true;
              allowDiscards = true;
            };
          }) (builtins.tail bcacheFsDevices)
        )
      );
}
