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
    "npm:@juicesharp/rpiv-ask-user-question@2.15.0"
    "npm:@vanillagreen/pi-tool-renderer@2.0.13"
    "npm:pi-blackhole@0.5.18"
    "npm:pi-claude-bridge@0.12.0"
    "npm:pi-commandcode-provider@0.8.2"
    "npm:pi-quiet-tools@0.2.0"
    # Edxeth v2.9.2; the npm package named pi-subagents belongs to Nico.
    "git:github.com/edxeth/pi-subagents@cf6dbf41c17986f3882e6804a68e8fb8282d25e6"
    "npm:pi-web-access@0.47.0"
  ];

  themeName = "catppuccin-frappe";
  settings = {
    defaultProvider = "openai-codex";
    defaultModel = "gpt-6-astra";
    defaultThinkingLevel = "medium";
    enabledModels = [
      "claude-bridge/claude-fable-5-2"
      "claude-bridge/claude-haiku-5-5"
      "claude-bridge/claude-opus-5-5"
      "claude-bridge/claude-sonnet-5-5"
      "commandcode/Qwen/Qwen3.8-Flash"
      "commandcode/Qwen/Qwen3.8-Max-0902"
      "commandcode/deepseek/deepseek-v4.1-flash"
      "commandcode/moonshotai/Kimi-K3"
      "commandcode/z-ai/glm-5.3-flash"
      "commandcode/zai-org/GLM-5.3"
      "openai-codex/gpt-6-astra"
      "openai-codex/gpt-6-luna"
      "openai-codex/gpt-6.1-sol"
      "openai-codex/gpt-6.1-terra"
    ];
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
    theme = themeName;
  };
  settingsJson = pkgs.writeText "pi-settings.json" (builtins.toJSON settings);

  subagents = {
    scout = {
      tools = "read,grep,find,ls,bash,caller_ping";
      description = "Inspect the codebase and report relevant files and execution paths. Do not edit files.";
      model = "openai-codex/gpt-6-luna";
      thinking = "low";
    };
    researcher = {
      tools = "read,web_enable,web_search,fetch_content,get_search_content,source_check,caller_ping";
      description = "Research the assigned question, cite sources, and distinguish verified findings from uncertainty. Do not edit files.";
      model = "openai-codex/gpt-6.1-sol";
      thinking = "high";
    };
    delegate = {
      tools = "all";
      description = "Complete a bounded delegated task and report results and validation.";
      model = "openai-codex/gpt-6.1-sol";
      thinking = "medium";
    };
    worker = {
      tools = "all";
      description = "Implement the assigned change, run focused validation, and report changed files and remaining risks.";
      model = "openai-codex/gpt-6-luna";
      thinking = "max";
    };
    reviewer = {
      tools = "read,grep,find,ls,caller_ping";
      description = "Review the assigned changes for concrete defects with source evidence. Do not edit files.";
      model = "openai-codex/gpt-6-astra";
      thinking = "xhigh";
    };
    oracle = {
      tools = "read,grep,find,ls,bash,caller_ping";
      description = "Analyze a difficult design or debugging question and recommend an evidence-based approach. Do not edit files.";
      model = "openai-codex/gpt-6-astra";
      thinking = "xhigh";
    };
  };

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

  piMemoryInit = pkgs.writeShellApplication {
    name = "pi-memory-init";
    runtimeInputs = [ pkgs.git ];
    text = ''
      exec ${lib.getExe pkgs.nushell} --no-config-file ${./memory-init.nu} "$@"
    '';
  };

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
  home.packages = [
    piWrapped
    piMemoryInit
  ];

  systemd.user.tmpfiles.rules = [
    "d %h/.pi/tmp 0700 - - 7d"
  ];

  home.file = {
    ".pi/agent/skills" = {
      source = ../agents/skills;
      recursive = true;
    };

    ".pi/agent/extensions" = {
      source = piExtensions;
      recursive = true;
    };

    ".pi/agent/AGENTS.md".source = ../agents/AGENTS.md;
    ".pi/agent/SYSTEM.md".text = ''
      You are a coding assistant operating inside Pi.

      ${builtins.readFile ../agents/PRINCIPLES.md}
      For Pi-specific implementation, read the relevant installed docs and examples
      under `$PI_PACKAGE_DIR` before changing behavior.

      Delegate only when the user explicitly authorizes subagents; task complexity
      alone is not authorization. Use Edxeth's named agents, not Nico's subagent API.
      Agent files define launch mode and working directory; tool calls cannot override
      them. Keep JJ workers in separate, explicitly prepared workspaces.
    '';
    ".pi/agent/mcp.json".text = builtins.toJSON mcp;
    ".pi/agent/models.json".text = builtins.toJSON models;
    ".pi/agent/claude-bridge.json".text = builtins.toJSON {
      provider = {
        plan = "max";
        pathToClaudeCodeExecutable = lib.getExe config.programs.claude-code.package;
      };
    };
    ".pi/agent/themes/${themeName}.json".source = ./themes/${themeName}.json;

  }
  // lib.mapAttrs' (
    name: agent:
    lib.nameValuePair ".pi/agent/agents/${name}.md" {
      text = ''
        ---
        name: ${name}
        description: ${agent.description}
        model: ${agent.model}
        thinking: ${agent.thinking}
        tools: ${agent.tools}
        allowed-models: ${lib.concatStringsSep "," settings.enabledModels}
        mode: background
        system-prompt: append
        inherit-append-system: true
        spawning: false
        ---

        ${agent.description}
        Follow the applicable project instructions. Stay within the assigned task.
        Do not publish, retain memories, or launch further agents. Ask the parent via
        caller_ping when blocked; report findings and checks to the parent.
      '';
    }
  ) subagents;

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
