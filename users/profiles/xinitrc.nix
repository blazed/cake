{ pkgs }:
{
  home.file.".xinitrc".text = ''
    #!/usr/bin/env sh

    ${pkgs.xorg.xrdb}/bin/xrdb -merge .Xresources

    exec i3
  '';
}
