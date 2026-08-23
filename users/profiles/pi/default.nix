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
  piJujutsu = pkgs.writeShellApplication {
    name = "jj";
    text = ''
      for argument in "$@"; do
        case "$argument" in
          --allow-private | --allow-private=*)
            echo "jj: --allow-private is disabled in Pi" >&2
            exit 2
            ;;
        esac
      done
      exec ${lib.getExe pkgs.jujutsu} "$@"
    '';
  };

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
      "git:github.com/DietrichGebert/ponytail@16f29800fd2681bdf24f3eb4ccffe38be3baec6b"
      "npm:@juicesharp/rpiv-ask-user-question@2.7.0"
      "npm:@vanillagreen/pi-tool-renderer@1.7.2"
      "npm:pi-blackhole@0.4.8"
      "npm:pi-mcp-adapter@2.27.0"
      "npm:pi-quiet-tools@0.2.0"
      "npm:pi-web-access@0.24.2"

      # testing
      "npm:pi-subagents@0.55.0"
      {
        source = "npm:remote-pi@0.5.5";
        extensions = [ ];
        skills = [ ];
        prompts = [ ];
        themes = [ ];
      }
    ];

  extraSkillDirs = [ ];

  extraExtensionPaths = [ ];

  themeName = "catppuccin-frappe";
  settings = {
    defaultProvider = "openai-codex";
    defaultModel = "gpt-5.6-luna";
    defaultThinkingLevel = "high";
    enableInstallTelemetry = false;
    enableSkillCommands = true;
    extensions = extraExtensionPaths;
    packages = thirdPartyPackages;
    skills = extraSkillDirs;
    steeringMode = "all";
    followUpMode = "all";
    showCacheMissNotices = true;
    subagents = {
      defaultModel = "openai-codex/gpt-5.6-terra";
      defaultThinking = "medium";
      modelScope = {
        enforce = true;
        allow = [
          "openai-codex/*"
          "opencode-go/*"
        ];
      };
      agentOverrides = {
        scout = {
          model = "openai-codex/gpt-5.6-luna";
          thinking = "low";
          fallbackModels = [ "opencode-go/deepseek-v4-flash:high" ];
        };
        researcher = {
          model = "opencode-go/deepseek-v4-flash";
          thinking = "max";
          fallbackModels = [ "openai-codex/gpt-5.6-terra:high" ];
        };
        delegate = {
          model = "openai-codex/gpt-5.6-terra";
          thinking = "medium";
        };
        worker = {
          model = "openai-codex/gpt-5.6-luna";
          thinking = "xhigh";
        };
        reviewer = {
          model = "openai-codex/gpt-5.6-sol";
          thinking = "xhigh";
        };
        oracle = {
          model = "openai-codex/gpt-5.6-sol";
          thinking = "xhigh";
          fallbackModels = [ "opencode-go/deepseek-v4-flash:max" ];
        };
      };
    };
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

  subagents = {
    claude.permissions = "full";
  };

  mcp = {
    mcpServers = {
      trakkt = {
        url = "https://trakkt.exsules.dev/mcp";
        auth = "oauth";
        oauth.scope = "mcp";
      };
    };
  };

  models = {
    providers = {
      "local-ai" = {
        baseUrl = "https://ai.tailef5cf.ts.net/v1";
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
        };
        models = [
          {
            id = "deepseek-v4-flash-0731:iq3";
            name = "DeepSeek V4 Flash 0731 IQ3";
            reasoning = true;
            thinkingLevelMap = {
              minimal = null;
              low = null;
              medium = null;
              high = "high";
              xhigh = null;
              max = "max";
            };
            input = [ "text" ];
            contextWindow = 131072;
            maxTokens = 32768;
            cost = {
              input = 0;
              output = 0;
              cacheRead = 0;
              cacheWrite = 0;
            };
            compat = {
              thinkingFormat = "chat-template";
              chatTemplateKwargs = {
                enable_thinking = {
                  "$var" = "thinking.enabled";
                };
                reasoning_effort = {
                  "$var" = "thinking.effort";
                };
              };
            };
          }
          {
            id = "deepseek-v4-flash-0731-abliterated:q2";
            name = "DeepSeek V4 Flash 0731 Abliterated Q2";
            reasoning = true;
            thinkingLevelMap = {
              minimal = null;
              low = null;
              medium = null;
              high = "high";
              xhigh = null;
              max = "max";
            };
            input = [ "text" ];
            contextWindow = 131072;
            maxTokens = 32768;
            cost = {
              input = 0;
              output = 0;
              cacheRead = 0;
              cacheWrite = 0;
            };
            compat = {
              thinkingFormat = "chat-template";
              chatTemplateKwargs.enable_thinking = {
                "$var" = "thinking.enabled";
              };
            };
          }
          {
            id = "qwen3.8-27b:q8";
            name = "Qwen3.8 27B Q8";
            reasoning = true;
            input = [ "text" ];
            contextWindow = 262144;
            maxTokens = 32768;
            cost = {
              input = 0;
              output = 0;
              cacheRead = 0;
              cacheWrite = 0;
            };
            compat = {
              thinkingFormat = "chat-template";
              chatTemplateKwargs = {
                enable_thinking = {
                  "$var" = "thinking.enabled";
                };
                preserve_thinking = true;
              };
            };
          }
          {
            id = "qwen3.8-27b:blackfrost-q8";
            name = "Qwen3.8 27B Blackfrost Q8";
            reasoning = true;
            input = [ "text" ];
            contextWindow = 262144;
            maxTokens = 32768;
            cost = {
              input = 0;
              output = 0;
              cacheRead = 0;
              cacheWrite = 0;
            };
            compat = {
              thinkingFormat = "chat-template";
              chatTemplateKwargs = {
                enable_thinking = {
                  "$var" = "thinking.enabled";
                };
                preserve_thinking = true;
              };
            };
          }
        ];
      };
    };
  };

  exaApiKeyCommand = pkgs.writeShellApplication {
    name = "pi-exa-api-key";
    runtimeInputs = [ pkgs.coreutils ];
    text = ''
      if [[ ! -r /run/agenix/exa-api-key ]]; then
        echo "Exa credential is unavailable" >&2
        exit 1
      fi
      cat /run/agenix/exa-api-key
    '';
  };
  webSearch = {
    provider = "exa";
    exaApiKey = "!${lib.getExe exaApiKeyCommand}";
    allowBrowserCookies = false;
    workflow = "none";
  };
  webSearchJson = pkgs.writeText "pi-web-search.json" (builtins.toJSON webSearch);

  localExtensionsCheck = pkgs.callPackage ./extension-check.nix { inherit piNode; };

  piExtensions = pkgs.runCommand "pi-extensions" { } ''
    test -e ${localExtensionsCheck}/result
    cp -r ${./extensions}/. $out
    chmod -R u+w $out
    rm -rf $out/subagents
  '';

  piWrapped = pkgs.symlinkJoin {
    name = "pi-wrapped";
    paths = [ piNode ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      ${lib.getExe piJujutsu} --version >/dev/null
      set +e
      rejection="$(${lib.getExe piJujutsu} git push --allow-private 2>&1)"
      rejectionStatus=$?
      set -e
      test "$rejectionStatus" -eq 2
      test "$rejection" = "jj: --allow-private is disabled in Pi"

      wrapProgram $out/bin/pi \
        --prefix PATH : ${lib.makeBinPath [ piJujutsu ]} \
        --run 'export TMPDIR="$HOME/.pi/tmp"; ${pkgs.coreutils}/bin/install -d -m 0700 "$TMPDIR"'
    '';
  };
in
{
  home.packages = [ piWrapped ];

  systemd.user.tmpfiles.rules = [
    "d %h/.pi/tmp 0700 - - 7d"
  ];

  home.file.".pi/agent/skills" = {
    source = ./skills;
    recursive = true;
  };

  home.file.".pi/agent/extensions" = {
    source = piExtensions;
    recursive = true;
  };

  # Subagents extension disabled (source kept at ./extensions/subagents).
  # Re-enable with: home.file.".pi/agent/extensions/subagents".source = pkgs.callPackage ./subagents-package.nix { inherit piNode; };

  home.file.".pi/agent/AGENTS.md".source = ./AGENTS.md;
  home.file.".pi/agent/mcp.json".text = builtins.toJSON mcp;
  home.file.".pi/agent/models.json".text = builtins.toJSON models;
  home.file.".pi/agent/subagents.json".text = builtins.toJSON subagents;
  home.file.".pi/agent/themes/${themeName}.json".source = ./themes/${themeName}.json;

  home.activation.piSettings = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run install -D -m0644 ${settingsJson} "${config.home.homeDirectory}/.pi/agent/settings.json"
  '';

  home.activation.piWebSearch = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    target="${config.xdg.configHome}/pi/web-search.json"
    if [[ -n "''${DRY_RUN:-}" ]]; then
      echo "Would merge Pi web-search defaults into $target"
    else
      ${pkgs.coreutils}/bin/install -d -m0700 "$(${pkgs.coreutils}/bin/dirname "$target")"
      temporary="$(${pkgs.coreutils}/bin/mktemp "$target.tmp.XXXXXX")"
      trap '${pkgs.coreutils}/bin/rm -f "$temporary"' EXIT
      if [ -f "$target" ]; then
        if ! ${lib.getExe pkgs.jq} -n \
          --slurpfile current "$target" \
          --slurpfile declared ${webSearchJson} \
          'if ($current | length) > 1 then error("multiple JSON documents") else ($current[0] // {}) * $declared[0] end' \
          > "$temporary"; then
          echo "warning: invalid existing Pi web-search config; preserving it as $target.invalid" >&2
          ${pkgs.coreutils}/bin/cp "$target" "$target.invalid"
          ${pkgs.coreutils}/bin/cp ${webSearchJson} "$temporary"
        fi
      else
        ${pkgs.coreutils}/bin/cp ${webSearchJson} "$temporary"
      fi
      ${pkgs.coreutils}/bin/chmod 0600 "$temporary"
      ${pkgs.coreutils}/bin/mv -f "$temporary" "$target"
      trap - EXIT
    fi
  '';
}
