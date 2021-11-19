{ pkgs, ... }:
{
  programs.firefox = {
    enable = true;
    package = pkgs.firefox-devedition-bin;
    extensions = with pkgs.nur.repos.rycee.firefox-addons; [
      https-everywhere
      privacy-badger
      ublock-origin
      facebook-container
      languagetool
      bitwarden
    ];
    profiles = {
      default = {
        settings = {
          # "media.peerconnection.enabled" = true;
          # "gfx.webrender.all" = true;
          # "media.ffmpeg.vaapi.enabled" = true;
          # "media.ffvpx.enabled" = true;
        };
      };
    };
  };
}
