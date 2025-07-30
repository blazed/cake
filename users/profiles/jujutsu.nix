{ pkgs, ... }:
{
  # home.packages = [pkgs.lazyjj];
  programs.jujutsu = {
    enable = true;
    ediff = false;
    settings = {
      user = {
        name = "Boberg";
        email = "1823919+blazed@users.noreply.github.com";
      };
      ui = {
        editor = "nvim";
        pager = "delta";
        diff.format = "git";
      };
    };
  };
}
