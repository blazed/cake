{ pkgs, ... }:
let
  extensions = [
    {
      ## vimium
      id = "dbepggeogbaibhgnhhndojpepiihcmeb";
    }
    {
      ## bitwarden
      id = "nngceckbapebfimnlniiiahkandclblb";
    }
    {
      ## Dark reader
      id = "eimadpbcbfnmbkopoojfekhnkhdbieeh";
    }
    {
      ## Language tool
      id = "oldceeleldhonbafppcapldpdifcinji";
    }
    {
      ## DuckDuckGo Privacy Essentials
      id = "bkdgflcldnnnapblkhphbgpggdiikppg";
    }
    {
      ## Imagus
      id = "immpkjjlgappgfkkfieppnmlhakdmaab";
    }
    {
      ## Privacy bagder
      id = "pkehgijcmpdhfbdbbnkijodmdjhbjlgp";
    }
    {
      ## uBlock Origin
      id = "cjpalhdlnbpafiamejdnhcphjbkeiagm";
    }
    {
      ## Consent-O-Matic
      id = "mdjildafknihdffpkfmmpnpoiajfjnjd";
    }
  ];
  commandLineArgs = [
    "-enable-features=UseOzonePlatform"
    "-ozone-platform=wayland"
    "-enable-features=VaapiVideoDecoder"
    "--enable-gpu"
  ];
in
{
  programs.chromium = {
    enable = true;
    inherit extensions commandLineArgs;
  };
  xdg.desktopEntries.chromium = {
    name = "Chromium";
    genericName = "Web Browser";
    exec = "chromium %U";
    terminal = false;
    categories = [
      "Network"
      "WebBrowser"
    ];
    mimeType = [
      "text/html"
      "text/xml"
    ];
    actions = {
      "New-Window" = {
        exec = "chromium --new-window %u";
      };
    };
  };
}
