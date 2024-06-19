{
  programs.git = {
    enable = true;
    delta = {
      enable = true;
      options.features = "decorations side-by-side line-numbers";
    };
    userName = "Boberg";
    userEmail = "1823919+blazed@users.noreply.github.com";
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
      gpg.format = "ssh";
      commit.gpgSign = true;
      tag.forceSignAnnotated = true;
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

  programs.gh = {
    enable = true;
    settings = {
      git_protocol = "ssh";
      prompt = "enabled";
      aliases = {
        co = "pr checkout";
        pv = "pr view";
      };
    };
  };
}
