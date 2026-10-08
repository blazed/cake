# Pi coding-agent profile with declarative settings, packages, extensions, themes,
# and the disk-backed temporary directory used by Pi. Skills and instructions live in ../agents.
{
  pkgs,
  inputs,
  lib,
  config,
  ...
}:
let
  piNode = import ./node-package.nix { inherit pkgs inputs; };
  piJujutsu = import ../agents/jj-guard.nix { inherit pkgs lib; };
  mergeJson = import ../agents/merge-json.nix { inherit pkgs lib; };

  thirdPartyPackages = [
    "npm:@juicesharp/rpiv-ask-user-question@2.12.0"
    "npm:@vanillagreen/pi-tool-renderer@2.0.10"
    "npm:pi-blackhole@0.5.11"
    "npm:pi-commandcode-provider@0.7.6"
    "npm:pi-quiet-tools@0.2.0"
    {
      source = "npm:pi-subagents@0.73.1";
      skills = [ "skills/pi-subagents/SKILL.md" ];
      prompts = [ "!prompts/council.md" ];
    }
    "npm:pi-web-access@0.37.0"
  ];

  themeName = "catppuccin-frappe";
  settings = {
    defaultTools = [
      "codemode"
    ];
    defaultProvider = "openai-codex";
    defaultModel = "gpt-6-astra";
    defaultThinkingLevel = "medium";
    enableInstallTelemetry = false;
    enableSkillCommands = true;
    packages = thirdPartyPackages;
    steeringMode = "all";
    followUpMode = "all";
    showCacheMissNotices = true;
    tuiMode = "regular";
    kendex.extensionManager.config."@vanillagreen/pi-tool-renderer" = {
      commandPreviewChars = 1000;
      registerBatchTool = false;
      renderBashDiffs = true;
      renderMutationTools = true;
    };
    subagents = {
      defaultModel = "openai-codex/gpt-5.6-sol";
      defaultThinking = "medium";
      modelScope = {
        enforce = true;
        allow = [
          "commandcode/*"
          "openai-codex/*"
        ];
      };
      agentOverrides = {
        scout = {
          model = "openai-codex/gpt-5.6-luna";
          thinking = "low";
        };
        researcher = {
          model = "openai-codex/gpt-5.6-sol";
          thinking = "high";
        };
        delegate = {
          model = "openai-codex/gpt-5.6-sol";
          thinking = "medium";
        };
        worker = {
          model = "openai-codex/gpt-5.6-luna";
          thinking = "max";
        };
        reviewer = {
          model = "openai-codex/gpt-6-astra";
          thinking = "xhigh";
        };
        oracle = {
          model = "openai-codex/gpt-6-astra";
          thinking = "xhigh";
        };
      };
    };
    theme = themeName;
  };
  settingsJson = pkgs.writeText "pi-settings.json" (builtins.toJSON settings);

  mcp = { };

  models = {
    providers = {
      anthropic = {
        modelOverrides."claude-fable-5-1".headers."user-agent" = "claude-cli/2.1.258";
      };
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
            id = "deepseek-v4-flash-0731-heretic:iq3";
            name = "DeepSeek V4 Flash 0731 Heretic v2 IQ3";
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
            thinkingLevelMap = {
              minimal = null;
              low = "low";
              medium = "medium";
              high = null;
              xhigh = "xhigh";
              max = null;
            };
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
            compat = {
              thinkingFormat = "chat-template";
              chatTemplateKwargs = {
                enable_thinking = {
                  "$var" = "thinking.enabled";
                };
                reasoning_effort = {
                  "$var" = "thinking.effort";
                };
                preserve_thinking = true;
              };
            };
          }
          {
            id = "qwen3.8-27b:rvn-ara-q8";
            name = "Qwen3.8 27B RVN ARA Q8";
            reasoning = true;
            thinkingLevelMap = {
              minimal = null;
              low = "low";
              medium = "medium";
              high = null;
              xhigh = "xhigh";
              max = null;
            };
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
            compat = {
              thinkingFormat = "chat-template";
              chatTemplateKwargs = {
                enable_thinking = {
                  "$var" = "thinking.enabled";
                };
                reasoning_effort = {
                  "$var" = "thinking.effort";
                };
                preserve_thinking = true;
              };
            };
          }
          {
            id = "qwen3.8-27b:rvn-ara-q6";
            name = "Qwen3.8 27B RVN ARA Q6";
            reasoning = true;
            thinkingLevelMap = {
              minimal = null;
              low = "low";
              medium = "medium";
              high = null;
              xhigh = "xhigh";
              max = null;
            };
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
            compat = {
              thinkingFormat = "chat-template";
              chatTemplateKwargs = {
                enable_thinking = {
                  "$var" = "thinking.enabled";
                };
                reasoning_effort = {
                  "$var" = "thinking.effort";
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
    provider = "auto";
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
      test "$rejection" = "jj: --allow-private is disabled for agents"

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
    source = ../agents/skills;
    recursive = true;
  };

  home.file.".pi/agent/extensions" = {
    source = piExtensions;
    recursive = true;
  };

  home.file.".pi/agent/AGENTS.md".source = ../agents/AGENTS.md;
  home.file.".pi/agent/SYSTEM.md".text = ''
    You are a coding assistant operating inside Pi.

    ${builtins.readFile ../agents/PRINCIPLES.md}
    For Pi-specific implementation, read the relevant installed docs and examples
    under `$PI_PACKAGE_DIR` before changing behavior.
  '';
  home.file.".pi/agent/mcp.json".text = builtins.toJSON mcp;
  home.file.".pi/agent/models.json".text = builtins.toJSON models;
  home.file.".pi/agent/themes/${themeName}.json".source = ./themes/${themeName}.json;

  home.file.".pi/agent/extensions/subagent/config.json".text = builtins.toJSON {
    toolDescriptionMode = "compact";
  };

  xdg.configFile."rpiv-ask-user-question/config.json".text = builtins.toJSON {
    guidance.description = ''
      Ask structured questions when a required decision cannot safely be inferred.
      Put a recommended option first and suffix it with (Recommended). Use previews
      only for single-select concrete alternatives. Never author Other or
      Type something. options.
    '';
  };

  home.activation.piSettings = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run install -D -m0644 ${settingsJson} "${config.home.homeDirectory}/.pi/agent/settings.json"
  '';

  home.activation.piWebSearch = lib.hm.dag.entryAfter [ "writeBoundary" ] (
    mergeJson "${config.xdg.configHome}/pi/web-search.json" webSearchJson
  );
}
