{
  lib,
  config,
  pkgs,
  ...
}:
let
  btrfsDisks = config.btrfs.disks;
  tmpfsRootSizeGb = config.tmpfsRoot.sizegb;
  # systemd 260's 99-systemd.rules marks any CRYPT-* dm device with no
  # detected partition table and no detected filesystem as SYSTEMD_READY=0
  # (to avoid acting on a half-formatted encrypted volume mid-mke2fs).
  # Our cryptkey is intentionally raw LUKS-wrapped key material, so it
  # always matches that rule and wedges the cryptkey -> encrypted_root
  # chain: dev-mapper-cryptkey.device never activates, encrypted_root
  # waits forever, and /dev/disk/by-label/root times out in initrd.
  # Shipped as 999-* so it sorts *after* 99-systemd.rules; the alternative
  # `boot.initrd.services.udev.rules` only writes 99-local.rules, which
  # sorts before 99-systemd.rules and is overwritten by it.
  cryptkeySystemdReadyOverride = pkgs.writeTextDir "lib/udev/rules.d/999-cryptkey-systemd-ready.rules" ''
    SUBSYSTEM=="block", ENV{DM_NAME}=="cryptkey", ENV{SYSTEMD_READY}="1"
  '';
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

  fileSystems."/nix" = {
    device = "/dev/disk/by-label/root";
    fsType = "btrfs";
    options = [
      "subvol=@nix"
      "rw"
      "noatime"
      "compress=zstd"
    ];
  };

  fileSystems."/keep" = {
    device = "/dev/disk/by-label/root";
    fsType = "btrfs";
    neededForBoot = true;
    options = [
      "subvol=@keep"
      "rw"
      "noatime"
      "compress=zstd"
    ];
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-label/boot";
    fsType = "vfat";
  };

  swapDevices = [ { device = "/dev/disk/by-label/swap"; } ];

  boot.initrd.supportedFilesystems = [
    "btrfs"
    "vfat"
  ];

  boot.initrd.services.udev.packages = [ cryptkeySystemdReadyOverride ];

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
          }) (builtins.tail btrfsDisks)
        )
      );

  services.btrfs.autoScrub.enable = true;
  services.btrfs.autoScrub.fileSystems = [
    "/nix"
    "/keep"
  ];
}
