{pkgs, ...}: {
  xresources.extraConfig = builtins.readFile (
    pkgs.fetchFromGitHub {
      owner = "pinpox";
      repo = "base16-xresources";
      rev = "fa0fe50d23c57515cf75c014044df3daf76f8d6f";
      sha256 = "sha256-G9n4+xpo4/FC2ixvec1z1FOTs+IlsFd32oeT5/pfrNo=";
    }
    + "/xresources/base16-onedark-256.Xresources"
  );

  xresources.properties = {
  };
}
