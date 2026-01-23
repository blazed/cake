{ config, pkgs, ... }:
let
  inherit (config) userinfo;
in
{
  programs.git = {
    enable = true;
    settings = {
      user.name = userinfo.fullName;
      user.email = userinfo.githubEmail;
      aliases = {
        co = "checkout";
        cob = "checkout -b";
      };
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
        interactive = "auto";
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
      ".aider*"
    ];
  };

  programs.delta = {
    enable = true;
    enableGitIntegration = true;
    options = {
      options.features = "decorations side-by-side line-numbers";
    };
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
    extensions = [
      pkgs.github-copilot-cli
    ];
  };
}
