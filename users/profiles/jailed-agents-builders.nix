{ pkgs, inputs }:
let
  inherit (pkgs.stdenv.hostPlatform) system;
  jail = inputs.jail-nix.lib.init pkgs;
  llm = inputs.llm-agents.packages.${system};
  piNode = import ./pi/node-package.nix { inherit pkgs inputs; };

  devTools = with pkgs; [
    # keep-sorted start
    bashInteractive
    curl
    diffutils
    fd
    findutils
    gawkInteractive
    gcc
    git
    gnugrep
    gnumake
    gnused
    gnutar
    jq
    jujutsu
    nodejs
    nushell
    proton-pass-cli
    ps
    python3
    ripgrep
    unzip
    which
    # keep-sorted end
  ];
  devToolsPath = pkgs.lib.makeBinPath devTools;
  cu = "${pkgs.coreutils}/bin";
  jjBin = "${pkgs.jujutsu}/bin/jj";

  forwardHostEnv =
    c: with c; [
      (ro-bind "/nix/store" "/nix/store")
      (add-runtime ''
        shopt -s nocasematch
        # Match secret-like names while preserving benign PWD and OLDPWD.
        __deny='^(AWS_|GH_|GITHUB_|OP_)|TOKEN|SECRET|KEY|PASSWORD|PASSWD|CREDENTIAL|_PWD$|^SSH_AUTH_SOCK$|^PATH$'
        # Also reject connection strings containing embedded passwords.
        __denyval='://[^@/]*:[^@/]+@'
        while IFS= read -r -d "" __kv; do
          __name=''${__kv%%=*}
          __val=''${__kv#*=}
          if [[ $__name =~ $__deny ]]; then continue; fi
          if [[ $__val =~ $__denyval ]]; then continue; fi
          RUNTIME_ARGS+=(--setenv "$__name" "$__val")
        done < <(${pkgs.coreutils}/bin/env -0)
        RUNTIME_ARGS+=(--setenv PATH "${devToolsPath}:$PATH")
      '')
    ];

  jjWorkspace =
    c: with c; [
      (add-runtime ''
        __jjuser=$(${jjBin} config get user.name 2>/dev/null) || __jjuser=""
        __jjemail=$(${jjBin} config get user.email 2>/dev/null) || __jjemail=""
        [ -n "$__jjuser" ] && RUNTIME_ARGS+=(--setenv JJ_USER "$__jjuser")
        [ -n "$__jjemail" ] && RUNTIME_ARGS+=(--setenv JJ_EMAIL "$__jjemail")
        # Avoid blocking on an unavailable interactive editor.
        RUNTIME_ARGS+=(--setenv JJ_EDITOR echo)
        __ws="$PWD"
        while [ "$__ws" != "/" ] && [ ! -e "$__ws/.jj" ]; do __ws=$(${cu}/dirname "$__ws"); done
        if [ -e "$__ws/.jj" ]; then
          RUNTIME_ARGS+=(--bind "$__ws" "$__ws")
          __repo="$__ws/.jj/repo"
          if [ -f "$__repo" ]; then
            __store=$(${cu}/realpath -m "$__ws/.jj/$(<"$__repo")")
          else
            __store="$__repo"
          fi
          if [ -e "$__store" ]; then
            RUNTIME_ARGS+=(--bind "$__store" "$__store")
            __gt="$__store/store/git_target"
            if [ -f "$__gt" ]; then
              __git=$(${cu}/realpath -m "$__store/store/$(<"$__gt")")
              [ -e "$__git" ] && RUNTIME_ARGS+=(--bind "$__git" "$__git")
            fi
          fi
        fi
      '')
    ];

  common =
    c:
    (with c; [
      network
      time-zone
      mount-cwd
      (try-readonly (noescape "~/.config/git/ignore"))
      no-new-session
      (try-fwd-env "TERM")
      (try-fwd-env "COLORTERM")
      (try-fwd-env "LANG")
      (add-pkg-deps devTools)
      (ro-bind "${pkgs.coreutils}/bin/env" "/usr/bin/env")
    ])
    ++ forwardHostEnv c
    ++ jjWorkspace c;

  permsFor =
    spec: c:
    common c
    ++ map (p: c.try-readwrite (c.noescape p)) (spec.paths or [ ])
    ++ (spec.extra or (_: [ ])) c;

  agents = {
    claude = {
      pkg = pkgs.writeShellScriptBin "claude" ''
        exec ${
          pkgs.lib.getExe inputs.claude-code.packages.${system}.default
        } --dangerously-skip-permissions "$@"
      '';
      paths = [
        "~/.claude"
        "~/.claude.json"
      ];
      extra = c: [ (c.try-fwd-env "ANTHROPIC_API_KEY") ];
    };
    codex = {
      pkg = pkgs.writeShellScriptBin "codex" ''
        exec ${pkgs.lib.getExe llm.codex} --dangerously-bypass-approvals-and-sandbox "$@"
      '';
      paths = [
        "~/.agents"
        "~/.codex"
      ];
      extra = c: [ (c.try-fwd-env "OPENAI_API_KEY") ];
    };
    pi = {
      pkg = piNode;
      paths = [
        "~/.agents"
        "~/.pi"
        "~/.config/pi"
      ];
      extra = c: [
        (c.add-runtime ''
          ${cu}/install -d -m 0700 "$HOME/.pi/tmp"
          RUNTIME_ARGS+=(--setenv TMPDIR "$HOME/.pi/tmp")
        '')
        (c.try-readonly (c.noescape "/run/agenix/exa-api-key"))
        (c.add-runtime ''
          RUNTIME_ARGS+=(
            --setenv PROTON_PASS_KEY_PROVIDER fs
            --setenv PROTON_PASS_SESSION_DIR /tmp/pass-agent-pi
          )
          if [ -r /run/agenix/proton-pass-agent-token ]; then
            RUNTIME_ARGS+=(
              --setenv PROTON_PASS_PERSONAL_ACCESS_TOKEN "$(${cu}/cat /run/agenix/proton-pass-agent-token)"
            )
          fi
        '')
      ];
    };
  };

  wrappersByName = pkgs.lib.mapAttrs (
    name: spec: jail "jailed-${name}" spec.pkg (permsFor spec)
  ) agents;
  wrappers = pkgs.lib.attrValues wrappersByName;

  agentNames = pkgs.lib.concatStringsSep "|" (builtins.attrNames agents);
  agentArms = pkgs.lib.concatStringsSep "\n" (
    pkgs.lib.mapAttrsToList (
      name: w: "            ${name}) bin=${w}/bin/jailed-${name} ;;"
    ) wrappersByName
  );

  hostAgentNames = "claude|codex|pi";
  hostAgentArms = ''
    claude) bin=${pkgs.lib.getExe inputs.claude-code.packages.${system}.default} ;;
    codex) bin=${pkgs.lib.getExe llm.codex} ;;
    pi) bin=${piNode}/bin/pi ;;
  '';

  mkLauncher =
    {
      name,
      agentNames,
      agentArms,
      mode,
    }:
    pkgs.writeShellApplication {
      inherit name;
      runtimeInputs = with pkgs; [
        jujutsu
        direnv
        coreutils
        gnugrep
      ];
      text = ''
              mainroot() {
                local root ptr store
                root=$(jj workspace root 2>/dev/null) || return 1
                ptr="$root/.jj/repo"
                if [ -f "$ptr" ]; then
                  store=$(realpath -m "$root/.jj/$(<"$ptr")")
                else
                  store="$ptr"
                fi
                dirname "$(dirname "$store")"
              }

              sub="''${1:-}"
              if [ "$#" -gt 0 ]; then shift; fi
              case "$sub" in
                new)
                  if [ "$#" -lt 2 ]; then
                    echo "usage: ${name} new <${agentNames}> <feature> [agent args...]" >&2
                    exit 2
                  fi
                  agent="$1"; shift
                  name="$1"; shift
                  case "$agent" in
        ${agentArms}
                    *) echo "unknown agent '$agent' (expected ${agentNames})" >&2; exit 2 ;;
                  esac
                  mr=$(mainroot) || { echo "not inside a jj repo" >&2; exit 1; }
                  ws="$(dirname "$mr")/$(basename "$mr")-$name"
                  if [ ! -e "$ws/.jj" ]; then
                    echo "creating jj workspace: $ws" >&2
                    jj workspace add --name "$name" "$ws"
                  fi
                  cd "$ws" || exit 1
                  if [ -f .envrc ]; then
                    direnv allow . || true
                    exec direnv exec "$PWD" "$bin" "$@"
                  fi
                  exec "$bin" "$@"
                  ;;
                rm)
                  force=0
                  name=""
                  for a in "$@"; do
                    case "$a" in
                      --force | -f) force=1 ;;
                      -*) echo "unknown flag '$a'" >&2; exit 2 ;;
                      *) name="$a" ;;
                    esac
                  done
                  if [ -z "$name" ]; then
                    echo "usage: ${name} rm <feature> [--force]" >&2
                    exit 2
                  fi
                  if [ "$name" = "default" ]; then
                    echo "refusing to remove the main (default) workspace" >&2
                    exit 1
                  fi
                  curroot=$(jj workspace root 2>/dev/null) || { echo "not inside a jj repo" >&2; exit 1; }
                  mr=$(mainroot) || { echo "not inside a jj repo" >&2; exit 1; }
                  ws="$(dirname "$mr")/$(basename "$mr")-$name"
                  if [ "$curroot" = "$ws" ]; then
                    echo "refusing to remove the workspace you're in; run from the main checkout" >&2
                    exit 1
                  fi
                  if ! jj workspace list | cut -d: -f1 | grep -qx "$name"; then
                    echo "no jj workspace named '$name'" >&2
                    exit 1
                  fi
                  if [ "$force" -ne 1 ]; then
                    if ! unsaved=$(jj log --no-graph --ignore-working-copy \
                      -r "(::$name@ ~ ::(bookmarks() | remote_bookmarks())) ~ empty()" \
                      -T '"x"' 2>/dev/null); then
                      echo "could not check '$name' for unsaved work (jj log failed); refusing to rm." >&2
                      echo "fix the repo, or pass --force if you're sure (commits stay in the op log)." >&2
                      exit 1
                    fi
                    if [ -n "$unsaved" ]; then
                      echo "workspace '$name' has commits not reachable from a bookmark:" >&2
                      jj log -r "(::$name@ ~ ::(bookmarks() | remote_bookmarks())) ~ empty()" >&2 || true
                      echo "bookmark or merge them first, or pass --force (commits stay in the op log)." >&2
                      exit 1
                    fi
                  fi
                  echo "forgetting workspace '$name' and removing $ws" >&2
                  jj workspace forget "$name"
                  rm -rf "$ws"
                  ;;
                ls)
                  mr=$(mainroot) || { echo "not inside a jj repo" >&2; exit 1; }
                  parent=$(dirname "$mr")
                  base=$(basename "$mr")
                  jj workspace list | while IFS= read -r line; do
                    n=''${line%%:*}
                    if [ "$n" = "default" ]; then
                      echo "$line"
                    elif [ -d "$parent/$base-$n" ]; then
                      echo "$line  -> $parent/$base-$n"
                    else
                      echo "$line  -> (dir missing: $parent/$base-$n)"
                    fi
                  done
                  ;;
                *)
                  echo "usage: ${name} <new|rm|ls> ..." >&2
                  echo "  new <${agentNames}> <feature> [args...]  create/enter a ${mode} agent workspace" >&2
                  echo "  rm  <feature> [--force]                    forget the workspace and remove its dir" >&2
                  echo "  ls                                         list workspaces and their dirs" >&2
                  exit 2
                  ;;
              esac
      '';
    };

  launcher = mkLauncher {
    name = "jailed-agent-ws";
    inherit agentNames agentArms;
    mode = "jailed";
  };
  hostLauncher = mkLauncher {
    name = "agent-ws";
    agentNames = hostAgentNames;
    agentArms = hostAgentArms;
    mode = "host";
  };
in
{
  inherit
    jail
    agents
    permsFor
    wrappers
    wrappersByName
    launcher
    hostLauncher
    ;
}
