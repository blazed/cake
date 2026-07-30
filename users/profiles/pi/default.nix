# Pi coding-agent profile with declarative settings, packages, skills, extensions,
# themes, and the disk-backed temporary directory used by Pi.
{
  pkgs,
  inputs,
  lib,
  config,
  ...
}:
let
  system = pkgs.stdenv.hostPlatform.system;
  piNode = import ./node-package.nix { inherit pkgs inputs; };
  piPackageDir = "${piNode}/lib/node_modules/@earendil-works/pi-coding-agent";

  # Packages installed by Pi through settings.packages.
  thirdPartyPackages =
    # Work around npm omitting remote-pi's optional native keyring dependency.
    lib.optionals (system == "x86_64-linux") [
      {
        source = "npm:@napi-rs/keyring-linux-x64-gnu@1.3.0";
        extensions = [ ];
        skills = [ ];
        prompts = [ ];
        themes = [ ];
      }
    ]
    ++ [
      "git:github.com/blazed/pi-openai-compaction@b087ebf12329a4da7bdd9376d3f7b28603cae2c1"
      "npm:@juicesharp/rpiv-ask-user-question@2.1.0"
      "npm:@plannotator/pi-extension@0.24.2"
      "npm:pi-claude-bridge@0.6.3"
      "npm:pi-hashline-edit@0.8.3"
      "npm:pi-web-access@0.14.0"
      "npm:remote-pi@0.5.5"
    ];

  extraSkillDirs = [ ];

  extraExtensionPaths = [ ];

  disabledLocalExtensions = [
    "dynamic-workflows/index.ts"
  ];
  localExtensionPaths =
    extraExtensionPaths ++ map (path: "-extensions/${path}") disabledLocalExtensions;

  themeName = "catppuccin-frappe";
  settings = {
    defaultProvider = "openai-codex";
    defaultModel = "gpt-5.6-sol";
    defaultThinkingLevel = "high";
    enableInstallTelemetry = false;
    enableSkillCommands = true;
    extensions = localExtensionPaths;
    packages = thirdPartyPackages;
    skills = extraSkillDirs;
    steeringMode = "all";
    followUpMode = "all";
    showCacheMissNotices = true;
    openaiNativeCompaction = {
      enabled = true;
      debug = false;
      logProviderPayloads = false;
      logCompactResponses = false;
      redactSensitiveData = true;
      supportedProviders = [
        "openai"
        "openai-codex"
      ];
      supportedApis = [
        "openai-responses"
        "openai-codex-responses"
      ];
      notifyOnLoad = false;
    };
    theme = themeName;
  };
  settingsJson = pkgs.writeText "pi-settings.json" (builtins.toJSON settings);

  claudeBridge = {
    askClaude = {
      enabled = false;
      allowFullMode = false;
      defaultMode = "read";
    };
    provider = {
      plan = "max";
      pathToClaudeCodeExecutable = lib.getExe inputs.claude-code.packages.${system}.default;
    };
  };

  # MCP servers (settings.mcpServers schema). Empty = no servers.
  mcp = {
    mcpServers = { };
  };

  # llama-swap exposes Qwen models through an OpenAI-compatible Tailscale endpoint.
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
    allowBrowserCookies = false;
    workflow = "none";
  };

  subagentsExtension = pkgs.buildNpmPackage {
    pname = "pi-subagents-extension";
    version = "0-unstable";
    src = ./extensions/subagents;
    npmDepsHash = "sha256-X0fJ3rmZUPuXjzrHjfAML4xph/IoHH1svavMJ7YCgVI=";

    buildPhase = ''
      runHook preBuild

      test -d ${piPackageDir}/node_modules/@earendil-works/pi-ai
      test -d ${piPackageDir}/node_modules/@earendil-works/pi-tui
      test -d ${piPackageDir}/node_modules/typebox
      mkdir -p node_modules/@earendil-works
      ln -s ${piPackageDir} node_modules/@earendil-works/pi-coding-agent
      ln -s ${piPackageDir}/node_modules/@earendil-works/pi-ai \
        node_modules/@earendil-works/pi-ai
      ln -s ${piPackageDir}/node_modules/@earendil-works/pi-tui \
        node_modules/@earendil-works/pi-tui
      ln -s ${piPackageDir}/node_modules/typebox node_modules/typebox

      npm run check
      npm test

      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall

      npm prune --omit=dev --ignore-scripts --offline
      rm -rf \
        node_modules/@earendil-works \
        node_modules/typebox \
        docs \
        *.test.ts \
        package-lock.json \
        tsconfig.json \
        src/backends/stub.ts
      mkdir -p $out
      cp -r index.ts package.json src node_modules $out/

      runHook postInstall
    '';
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
    rm -rf $out/subagents
    install -Dm444 ${acornVendor}/acorn.mjs $out/dynamic-workflows/vendor/acorn.mjs
    install -Dm444 ${acornVendor}/ACORN-LICENSE $out/dynamic-workflows/vendor/ACORN-LICENSE
  '';

  piWithExa = pkgs.symlinkJoin {
    name = "pi-with-exa";
    paths = [ piNode ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram $out/bin/pi \
        --run 'export TMPDIR="$HOME/.pi/tmp"; ${pkgs.coreutils}/bin/install -d -m 0700 "$TMPDIR"' \
        --run 'if [ -z "''${EXA_API_KEY:-}" ] && [ -r /run/agenix/exa-api-key ]; then export EXA_API_KEY="$(< /run/agenix/exa-api-key)"; fi'
    '';
  };
in
{
  home.packages = [ piWithExa ];

  # Keep Pi's inspectable temporary output off the tmpfs root and expire it.
  systemd.user.tmpfiles.rules = [
    "d %h/.pi/tmp 0700 - - 7d"
  ];

  # Keep these directories writable alongside third-party installations.
  home.file.".pi/agent/skills" = {
    source = ./skills;
    recursive = true;
  };

  home.file.".pi/agent/extensions" = {
    source = piExtensions;
    recursive = true;
  };

  # Keep the dependency-heavy extension as one directory symlink instead of
  # asking Home Manager to create a link for every file in node_modules.
  home.file.".pi/agent/extensions/subagents".source = subagentsExtension;

  # Read-only Nix-managed configuration.
  home.file.".pi/agent/AGENTS.md".source = ./AGENTS.md;
  home.file.".pi/agent/claude-bridge.json".text = builtins.toJSON claudeBridge;
  home.file.".pi/agent/mcp.json".text = builtins.toJSON mcp;
  home.file.".pi/agent/models.json".text = builtins.toJSON models;
  home.file.".pi/web-search.json".text = builtins.toJSON webSearch;
  home.file.".pi/agent/themes/${themeName}.json".source = ./themes/${themeName}.json;

  # Pi writes lastChangelogVersion, so install a writable settings copy.
  home.activation.piSettings = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run install -D -m0644 ${settingsJson} "${config.home.homeDirectory}/.pi/agent/settings.json"
  '';
}
