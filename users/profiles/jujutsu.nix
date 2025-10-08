{ config, ... }:
let
  inherit (config) userinfo;
in
{
  programs.jujutsu = {
    enable = true;
    ediff = false;
    settings = {
      user = {
        email = userinfo.githubEmail;
        name = userinfo.fullName;
      };
      ui = {
        editor = "nvim";
        pager = "delta";
        diff-formatter = [
          "difft"
          "--color=always"
          "$left"
          "$right"
        ];
      };
    };
  };
}
