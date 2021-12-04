{ config, ... }:
let
   extraConfig = config.home.extraConfig;
in
{
  programs.git = {
    enable = true;
    delta = {
      enable = true;
      options.features = "decorations side-by-side line-numbers";
    };
    userName = "Boberg";
    userEmail = extraConfig.userEmail;
    aliases = {
      co = "checkout";
      cob = "checkout -b";
    };
    extraConfig = {
      core = {
        quotepath = false;
        editor = "nvim";
        whitespace = "cr-at-eol";
      };
      init.defaultBranch = "main";
      pull.rebase = true;
      push.default = "simple";
      push.followTags = "true";
      color = {
        diff = "auto";
        status = "auto";
        branch = "auto";
        interacive = "auto";
        ui = true;
        pager = true;
      };
      url."git@github.com:".insteadOf = "https://github.com/";
      advice.pushnonfastforward = false;
      branch.autosetuprebase = "always";
      rebase.autosquash = true;
      rebase.autostash = true;
      rebase.instructionformat = "[%an - %ar] %s";
      rerere.enabled = true;
      rerere.autoupdate = true;
    };

    ignores = [
      ".nvimlog" # TODO(blazed): find out why this is needed?
    ];
  };
}
