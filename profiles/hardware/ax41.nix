{inputs, ...}: {
  imports = [
    ./amd.nix
    inputs.nixos-hardware.nixosModules.common-cpu-amd
  ];

  fileSystems."/nix".options = ["subvol=@nix" "rw" "noatime" "compress=zstd"];
  fileSystems."/keep".options = ["subvol=@keep" "rw" "noatime" "compress=zstd"];
}
