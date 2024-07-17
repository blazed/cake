{pkgs, config, ...}: let
  inherit (config) userinfo;
in {
  programs.rbw.enable = true;
  programs.rbw.settings = {
    inherit (userinfo) email;
    lock_timeout = 3600;
    pinentry = pkgs.pinentry-gnome3;
  };
}
