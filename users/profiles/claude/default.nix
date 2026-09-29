# Claude Code profile. Shares instructions and skills with Pi through ../agents
# and pins plugins through flake inputs so every machine matches.
{
  pkgs,
  inputs,
  lib,
  config,
  ...
}:
let
  inherit (pkgs.stdenv.hostPlatform) system;
  claudeCode = inputs.claude-code.packages.${system}.default;
  officialPlugins = inputs.claude-plugins-official;
  jjGuard = import ../agents/jj-guard.nix { inherit pkgs lib; };
  mergeJson = import ../agents/merge-json.nix { inherit pkgs lib; };

  # Keep the version in the name so Home Manager detects personal-plugin support.
  claudeWrapped = pkgs.symlinkJoin {
    name = "claude-code-${claudeCode.version}";
    paths = [ claudeCode ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram $out/bin/claude --prefix PATH : ${lib.makeBinPath [ jjGuard ]}
    '';
    inherit (claudeCode) meta;
  };

  statusLine = pkgs.writeShellApplication {
    name = "claude-statusline";
    runtimeInputs = [
      pkgs.git
      pkgs.jq
      pkgs.jujutsu
    ];
    text = builtins.readFile ./statusline.sh;
  };

  # Merged over ~/.claude/settings.json on activation instead of symlinked,
  # because Claude Code writes to that file at runtime (/config, /model, ...).
  settings = {
    env = {
      CLAUDE_BASH_MAINTAIN_PROJECT_WORKING_DIR = "1";
      DISABLE_BUG_COMMAND = "1";
      DISABLE_ERROR_REPORTING = "1";
      DISABLE_TELEMETRY = "1";
      DISABLE_NON_ESSENTIAL_MODEL_CALLS = "1";
      JJ_EDITOR = "echo";
      CLAUDE_AUTOCOMPACT_PCT_OVERRIDE = "50";
    };
    includeCoAuthoredBy = false;
    permissions.allow = [
      "Bash(find:*)"
      "Bash(rg:*)"
      "Bash(echo:*)"
      "Bash(grep:*)"
      "Bash(ls:*)"
      "Bash(gh pr list:*)"
      "Bash(gh pr view:*)"
      "Bash(gh pr diff:*)"
    ];
    model = "opus";
    hooks.Notification = [
      {
        matcher = "";
        hooks = [
          {
            type = "command";
            command = "${lib.getExe' pkgs.libnotify "notify-send"} 'Claude Code' 'Claude Code needs your attention'";
          }
        ];
      }
    ];
    enableArtifact = false;
    statusLine = {
      type = "command";
      command = lib.getExe statusLine;
    };
    alwaysThinkingEnabled = true;
    effortLevel = "xhigh";
    tui = "fullscreen";
    skipDangerousModePermissionPrompt = true;
    editorMode = "normal";
    switchModelsOnFlag = false;
    autoContinueAtUsageLimit = false;
  };
  settingsJson = pkgs.writeText "claude-settings.json" (builtins.toJSON settings);
in
{
  home.packages = [ pkgs.python3 ];

  programs.claude-code = {
    enable = true;
    package = claudeWrapped;
    context = builtins.readFile ../agents/AGENTS.md + "\n" + builtins.readFile ../agents/PRINCIPLES.md;
    skills = ../agents/skills;
    mcpServers.trakkt = {
      type = "http";
      url = "https://trakkt.exsules.dev/mcp";
    };
    plugins = {
      frontend-design = "${officialPlugins}/plugins/frontend-design";
      playwright = "${officialPlugins}/external_plugins/playwright";
      rust-analyzer-lsp = "${officialPlugins}/plugins/rust-analyzer-lsp";
      typescript-lsp = "${officialPlugins}/plugins/typescript-lsp";
    };
  };

  home.activation.claudeSettings = lib.hm.dag.entryAfter [ "writeBoundary" ] (
    mergeJson "${config.programs.claude-code.configDir}/settings.json" settingsJson
  );
}
