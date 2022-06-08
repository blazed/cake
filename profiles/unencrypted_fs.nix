{
  fileSystems."/" = {
    device = "none";
    fsType = "tmpfs";
    options = ["defaults" "size=8G" "mode=755"];
  };

  fileSystems."/nix" = {
    device = "/dev/disk/by-label/root";
    fsType = "btrfs";
    options = ["subvol=@nix" "rw" "noatime" "compress=zstd" "ssd" "space_cache"];
  };

  fileSystems."/keep" = {
    device = "/dev/disk/by-label/root";
    fsType = "btrfs";
    neededForBoot = true;
    options = ["subvol=@keep" "rw" "noatime" "compress=zstd" "ssd" "space_cache"];
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-label/boot";
    fsType = "vfat";
  };

  swapDevices = [{device = "/dev/disk/by-label/swap";}];
}
