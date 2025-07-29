{ pkgs, ... }:
{
  home.packages = with pkgs; [
    claude-code
    python3
  ];
}
