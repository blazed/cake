{ config, ... }:
let
  inherit (config) userinfo;
in
{
  programs.jujutsu = {
    enable = true;
    ediff = false;
    settings = {
      aliases = {
        tug = [
          "bookmark"
          "move"
          "--from"
          "heads(::@- & bookmarks())"
          "--to"
          "@"
        ];
        tug- = [
          "bookmark"
          "move"
          "--from"
          "heads(::@- & bookmarks())"
          "--to"
          "@-"
        ];
      };
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
