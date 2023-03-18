{
  hardware.cpu.intel.updateMicrocode = true;
  boot.kernelModules = ["kvm-intel"];

  fileSystems."/nix".options = ["subvol=@nix" "rw" "noatime" "compress=zstd"];
  fileSystems."/keep".options = ["subvol=@keep" "rw" "noatime" "compress=zstd"];
}
