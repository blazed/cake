{ pkgs, ... }:
let
  firefox = pkgs.firefox.override {
    nativeMessagingHosts = [ pkgs.tridactyl-native ];
  };
in
{
  programs.firefox = {
    enable = true;
    package = firefox;
    profiles = {
      default = {
        extensions.packages = with pkgs.nur.repos.rycee.firefox-addons; [
          bitwarden
          consent-o-matic
          duckduckgo-privacy-essentials
          privacy-badger
          tridactyl
          ublock-origin
        ];
        settings = {
          "browser.compactmode.show" = true;
          "browser.startup.homepage" = "";
          "browser.bookmarks.showMobileBookmarks" = true;
          "browser.tabs.opentabfor.middleclick" = false;
          "toolkit.legacyUserProfileCustomizations.stylesheets" = true;
          "media.peerconnection.enabled" = true;
          "gfx.webrender.all" = true;
          "media.ffmpeg.vaapi.enabled" = true;
          "media.rdd-ffmpeg.enabled" = true;
          "media.ffvpx.enabled" = false;
          "media.navigator.mediadatadecoder_vpx_enabled" = true;
          "media.rdd-vpx.enabled" = false;
        };
      };
    };
  };
}
