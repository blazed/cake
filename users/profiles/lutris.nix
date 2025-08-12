{ pkgs, ... }:
{
  programs.lutris = {
    enable = true;
    protonPackages = with pkgs; [
      proton-ge-bin
    ];
  };
}
