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
    "npm:@blazed/plannotator-pi-extension@0.20.3-blazed.3"
    "npm:@juicesharp/rpiv-ask-user-question@1.20.0"
    "npm:@juicesharp/rpiv-todo@1.20.0"
    "npm:pi-hashline-readmap@0.11.1"
    "npm:pi-web-access@0.13.0"
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

  themeName = "catppuccin-frappe";
  settings = {
    defaultProvider = "openai-codex";
    defaultModel = "gpt-5.5";
    defaultThinkingLevel = "xhigh";
    enableInstallTelemetry = false;
    enableSkillCommands = true;
    extensions = localExtensionPaths;
    packages = thirdPartyPackages;
    skills = extraSkillDirs;
    steeringMode = "all";
    followUpMode = "all";
    theme = themeName;
  };
  settingsJson = pkgs.writeText "pi-settings.json" (builtins.toJSON settings);

  # MCP servers (settings.mcpServers schema). Empty = no servers.
  mcp = {
    mcpServers = { };
  };

  # Custom providers/models. llama-swap exposes an OpenAI-compatible API over
  # Tailscale HTTPS; Qwen models use llama.cpp's Qwen chat-template thinking
  # control, which Pi enables via compat.thinkingFormat = "qwen-chat-template".
  models = {
    providers = {
      "margot" = {
        baseUrl = "https://margot.tailef5cf.ts.net/v1";
        api = "openai-responses";
        apiKey = "llama-swap";
        compat = {
          supportsStore = false;
          supportsDeveloperRole = false;
          supportsReasoningEffort = false;
          supportsUsageInStreaming = false;
          maxTokensField = "max_tokens";
          supportsStrictMode = false;
          supportsLongCacheRetention = false;
          thinkingFormat = "qwen-chat-template";
        };
        models =
          map
            (id: {
              inherit id;
              name = id;
              reasoning = true;
              input = [
                "text"
                "image"
              ];
              contextWindow = 262144;
              maxTokens = 32768;
              cost = {
                input = 0;
                output = 0;
                cacheRead = 0;
                cacheWrite = 0;
              };
            })
            [
              "qwen3.6:27b-mtp-q4"
              "qwen3.6:27b-mtp-q8"
              "qwen3.6:27b-q4"
              "qwen3.6:27b-q8"
              "qwen3.6:35b-a3b-mtp-q4"
              "qwen3.6:35b-a3b-mtp-q8"
              "qwen3.6:35b-a3b-q4"
              "qwen3.6:35b-a3b-q8"
            ];
      };
    };
  };

  webSearch = {
    provider = "exa";
    allowBrowserCookies = false; # keep it pure-HTTP; never spawn Chromium
    workflow = "none";
  };

  acornVendor =
    let
      src = pkgs.fetchurl {
        url = "https://registry.npmjs.org/acorn/-/acorn-8.16.0.tgz";
        hash = "sha256-i63KCtwCuJgHx/mlMMLNULQLqrFK3nr1O3BPGYqr4R4=";
      };
    in
    pkgs.runCommand "acorn-8.16.0-vendor" { } ''
      tar -xzf ${src} package/dist/acorn.mjs package/LICENSE
      install -Dm444 package/dist/acorn.mjs $out/acorn.mjs
      install -Dm444 package/LICENSE $out/ACORN-LICENSE
    '';

  piExtensions = pkgs.runCommand "pi-extensions" { } ''
    cp -r ${./extensions}/. $out
    chmod -R u+w $out
    install -Dm444 ${acornVendor}/acorn.mjs $out/dynamic-workflows/vendor/acorn.mjs
    install -Dm444 ${acornVendor}/ACORN-LICENSE $out/dynamic-workflows/vendor/ACORN-LICENSE
  '';

  piWithExa = pkgs.symlinkJoin {
    name = "pi-with-exa";
    paths = [ pi ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram $out/bin/pi \
        --run 'if [ -z "''${EXA_API_KEY:-}" ] && [ -r /run/agenix/exa-api-key ]; then export EXA_API_KEY="$(< /run/agenix/exa-api-key)"; fi'
    '';
  };
in
{
  home.packages = [
    piWithExa
    agent-browser
  ];

  # Self-authored skills & extensions (per-file symlinks; parent dirs writable).
  home.file.".pi/agent/skills" = {
    source = ./skills;
    recursive = true;
  };

  home.file.".pi/agent/extensions" = {
    source = piExtensions;
    recursive = true;
  };

  # Read-only Nix-managed config (Pi only reads these).
  home.file.".pi/agent/AGENTS.md".source = ./AGENTS.md;
  home.file.".pi/agent/mcp.json".text = builtins.toJSON mcp;
  home.file.".pi/agent/models.json".text = builtins.toJSON models;
  home.file.".pi/web-search.json".text = builtins.toJSON webSearch;
  home.file.".pi/agent/themes/${themeName}.json".source = ./themes/${themeName}.json;

  # settings.json must be WRITABLE (Pi appends lastChangelogVersion). Install a
  # real copy from the generated store file; re-copied each switch so Nix wins.
  home.activation.piSettings = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run install -D -m0644 ${settingsJson} "${config.home.homeDirectory}/.pi/agent/settings.json"
  '';
}
