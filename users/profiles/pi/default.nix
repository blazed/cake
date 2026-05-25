# Pi coding agent (https://pi.dev, from inputs.llm-agents) as an extensible,
# first-class harness profile. Installs the plain `pi` command alongside the
# existing `jailed-pi` wrapper (jailed-agents-builders.nix).
#
# Layout under ~/.pi/agent/ (paths in settings.json resolve relative to it):
#   settings.json - generated from Nix; installed as a WRITABLE copy because Pi
#                   appends a cosmetic `lastChangelogVersion` at runtime
#                   (re-copied on each switch, so Nix stays authoritative).
#   mcp.json / models.json / AGENTS.md - Nix-managed read-only store symlinks
#                   (Pi only reads them).
#   skills/ extensions/ - self-authored, per-file symlinks (recursive) so the
#                   dirs stay writable and coexist with third-party auto-installs.
#   auth.json     - UNMANAGED: written 0600 by `pi /login`, persisted via
#                   impermanence (profiles/state.nix). Never touched here.
{
  pkgs,
  inputs,
  lib,
  config,
  ...
}:
let
  system = pkgs.stdenv.hostPlatform.system;
  llm = inputs.llm-agents.packages.${system};
  inherit (llm) pi;
  # Browser-automation CLI for agents (Vercel Labs). The llm-agents build bundles
  # a Nix Chromium, so it works on NixOS with no Chrome download / nix-ld.
  inherit (llm) agent-browser;

  # ---- Declarative extensibility knobs --------------------------------------
  # THIRD-PARTY extensions Pi auto-installs (settings.packages):
  thirdPartyPackages = [
    "npm:@juicesharp/rpiv-ask-user-question@1.13.0"
    "npm:@juicesharp/rpiv-todo@1.13.0"
    "npm:pi-hashline-edit@0.6.1"
    # "npm:pi-hashline-readmap@0.8.14"
  ];

  # Extra SKILL dirs beyond the auto-discovered ~/.pi/agent/skills + ~/.agents/skills:
  extraSkillDirs = [
    # Official agent-browser skill, shipped inside the package and version-matched
    # to the CLI. A discovery stub that loads real workflows on demand via
    # `agent-browser skills get core`.
    "${agent-browser}/share/agent-browser/skills"
    # "~/.claude/skills"   # reuse Claude Code skills, if wanted
  ];

  # Local extension FS paths outside the auto-discovered dir (rarely needed):
  localExtensionPaths = [ ];

  settings = {
    defaultProvider = "opencode-go";
    defaultModel = "deepseek-v4-flash";
    defaultThinkingLevel = "high";
    enableInstallTelemetry = false;
    enableSkillCommands = true;
    extensions = localExtensionPaths;
    packages = thirdPartyPackages;
    skills = extraSkillDirs;
    steeringMode = "all";
    followupMode = "all";
  };
  settingsJson = pkgs.writeText "pi-settings.json" (builtins.toJSON settings);

  # MCP servers (settings.mcpServers schema). Empty = no servers.
  mcp = {
    mcpServers = { };
  };

  # Custom providers/models. Empty = use Pi's built-ins only.
  models = {
    providers = { };
  };
in
{
  home.packages = [
    pi
    agent-browser
  ];

  # Self-authored skills & extensions (per-file symlinks; parent dirs writable).
  home.file.".pi/agent/skills" = {
    source = ./skills;
    recursive = true;
  };
  home.file.".pi/agent/extensions" = {
    source = ./extensions;
    recursive = true;
  };

  # Read-only Nix-managed config (Pi only reads these).
  home.file.".pi/agent/AGENTS.md".source = ./AGENTS.md;
  home.file.".pi/agent/mcp.json".text = builtins.toJSON mcp;
  home.file.".pi/agent/models.json".text = builtins.toJSON models;

  # settings.json must be WRITABLE (Pi appends lastChangelogVersion). Install a
  # real copy from the generated store file; re-copied each switch so Nix wins.
  home.activation.piSettings = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run install -D -m0644 ${settingsJson} "${config.home.homeDirectory}/.pi/agent/settings.json"
  '';
}
