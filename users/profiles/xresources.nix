{pkgs}: {
  xresources.extraConfig = builtins.readFile (
    pkgs.fetchFromGitHub {
      owner = "base16-templates";
      repo = "base16-xresources";
      rev = "d762461de45e00c73a514408988345691f727632";
      sha256 = "08msc3mgf1qzz6j82gi10fin12iwl2zh5annfgbp6nkig63j6fcx";
    }
    + "/xresources/base16-onedark-256.Xresources"
  );

  xresources.properties = {
  };
}
