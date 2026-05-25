# Pure builders for the jailed agent wrappers.
#
# This is the single source of truth for the bubblewrap permission set. It is
# consumed by the home-manager profile (./jailed-agents.nix, which installs
# `wrappers`) and by the NixOS tests under ../../tests: jail-leak-audit.nix wraps
# an audit payload with `permsFor agents.claude`, and jail-jj-workspace.nix
# exercises the same sandbox from inside a jj workspace. Keeping the permissions
# here means the tests exercise the exact sandbox the agents run in — a leaky
# bind added to `common` would make the audit fail.
{ pkgs, inputs }:
let
  inherit (pkgs.stdenv.hostPlatform) system;
  jail = inputs.jail-nix.lib.init pkgs;
  llm = inputs.llm-agents.packages.${system};

  # Tools on PATH inside every jail. Deliberately excludes gcloud/kubectl/aws/ssh
  # so a runaway agent can't reach cloud or remote credentials.
  devTools = with pkgs; [
    # keep-sorted start
    bashInteractive
    curl
    diffutils
    fd
    findutils
    gawkInteractive
    git
    gnugrep
    gnused
    gnutar
    jq
    jujutsu
    nodejs
    nushell
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

  # Make the agent usable inside a devenv/direnv-activated project: mount the
  # whole store read-only (so devenv-provided tools resolve) and forward the
  # caller's environment + PATH into the jail, MINUS secret-looking variables.
  # The agent's own API key is forwarded explicitly via each agent's `extra`.
  # Curated devTools are prepended to PATH so they're always present, with the
  # project's (devenv) PATH after them.
  forwardHostEnv =
    c: with c; [
      (ro-bind "/nix/store" "/nix/store")
      (add-runtime ''
        shopt -s nocasematch
        # Drop secret-looking vars by NAME. Case-insensitive (nocasematch).
        # `_PWD$` catches MySQL's documented plaintext-password var MYSQL_PWD
        # (and DB_PWD/REDIS_PWD/…) without stripping the benign PWD/OLDPWD (no
        # underscore before PWD there).
        __deny='^(AWS_|GH_|GITHUB_|OP_)|TOKEN|SECRET|KEY|PASSWORD|PASSWD|CREDENTIAL|_PWD$|^SSH_AUTH_SOCK$|^PATH$'
        # Also drop by VALUE: connection strings with embedded credentials
        # (scheme://user:pass@host — DATABASE_URL/POSTGRES_URL/MONGODB_URI/…),
        # whatever the var is named. Requires a `:password@`, so credential-free
        # URLs (OPENAI_BASE_URL=http://host:port) and ssh://git@host remotes stay.
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

  # Make jj usable inside the jail. We deliberately do NOT bind the user's
  # ~/.config/jj: it commonly enables SSH commit signing, which can't work in the
  # jail (no ssh-keygen, and the signing key lives in ~/.ssh which we block on
  # purpose). Instead we inject just the identity via JJ_USER/JJ_EMAIL (read from
  # the host config) — jailed commits are unsigned; you sign on review/merge.
  # We also force JJ_EDITOR=echo so editor-driven commands (squash/split/describe)
  # don't hang on a missing interactive editor in the jail.
  #
  # When $PWD is in a jj repo we also auto-bind the workspace root, the shared
  # repo store (resolved from the .jj/repo pointer), and the colocated .git, all
  # rw at their real paths. This lets several agents work the same repo in
  # separate jj workspaces; each jail sees only its own workspace's working tree
  # plus the shared history. No-op outside a jj repo.
  jjWorkspace =
    c: with c; [
      (add-runtime ''
        __jjuser=$(${jjBin} config get user.name 2>/dev/null) || __jjuser=""
        __jjemail=$(${jjBin} config get user.email 2>/dev/null) || __jjemail=""
        [ -n "$__jjuser" ] && RUNTIME_ARGS+=(--setenv JJ_USER "$__jjuser")
        [ -n "$__jjemail" ] && RUNTIME_ARGS+=(--setenv JJ_EMAIL "$__jjemail")
        # Editor-driven jj commands (squash/split/describe with no -m, etc.) would
        # block on an interactive editor in the jail; point JJ_EDITOR at a no-op so
        # they fall back to the existing description instead of hanging. This is
        # appended after forwardHostEnv, so it wins over any inherited JJ_EDITOR.
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

  # Permissions shared by every jailed agent.
  common =
    c:
    (with c; [
      network # API calls (and local llama on :9292 if used)
      time-zone
      mount-cwd # current project dir, read-write
      no-new-session # interactive TUIs need to feed input to the terminal
      (try-fwd-env "TERM")
      (try-fwd-env "COLORTERM")
      (try-fwd-env "LANG")
      (add-pkg-deps devTools)
      # Provide /usr/bin/env so `#!/usr/bin/env bash|sh|nu|...` shebangs work for
      # scripts the agent runs; the interpreters are on the in-jail PATH.
      (ro-bind "${pkgs.coreutils}/bin/env" "/usr/bin/env")
    ])
    ++ forwardHostEnv c
    ++ jjWorkspace c;

  # Build the permission list for an agent spec: shared baseline + the agent's
  # own read-write config paths (~ expands at runtime) + any extra combinators
  # (e.g. forwarded API-key env vars).
  permsFor =
    spec: c:
    common c
    ++ map (p: c.try-readwrite (c.noescape p)) (spec.paths or [ ])
    ++ (spec.extra or (_: [ ])) c;

  # name -> { pkg; paths?; extra?; }
  agents = {
    claude = {
      # github:sadjow/claude-code-nix, defaulted to YOLO mode — safe because the
      # jail is the boundary. User args are still passed through.
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
      # github:numtide/llm-agents.nix, defaulted to YOLO mode (jail is the boundary).
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
      pkg = llm.pi; # github:numtide/llm-agents.nix
      paths = [
        "~/.agents"
        "~/.pi"
      ];
      # agent-browser is installed unjailed via the pi profile, but it lives on the
      # host's home-manager PATH (e.g. /etc/profiles/per-user/.../bin) which isn't
      # bound in the jail, so `agent-browser` isn't found inside jailed-pi. Re-add
      # its store bin to the in-jail PATH at runtime. This add-runtime is appended
      # AFTER forwardHostEnv's PATH setenv (extra runs after common), so it wins; we
      # re-include devToolsPath so the curated dev tools stay on PATH. The bundled
      # Chromium is invoked by absolute path (wrapper env) via the ro /nix/store
      # mount — though launching it under bubblewrap may need extra sandbox perms.
      extra = c: [
        (c.add-runtime ''RUNTIME_ARGS+=(--setenv PATH "${llm.agent-browser}/bin:${devToolsPath}:$PATH")'')
        # pi-web-access's web_search uses Exa. The jail can't read /run/agenix, but
        # this wrapper runs on the HOST before bwrap — so read the exa-api-key
        # agenix secret here and inject it as EXA_API_KEY (env overrides the
        # ~/.pi/web-search.json provider config). Best-effort: only if present.
        (c.add-runtime ''
          if [ -r /run/agenix/exa-api-key ]; then
            RUNTIME_ARGS+=(--setenv EXA_API_KEY "$(${cu}/cat /run/agenix/exa-api-key)")
          fi
        '')
      ];
    };
  };

  wrappersByName = pkgs.lib.mapAttrs (
    name: spec: jail "jailed-${name}" spec.pkg (permsFor spec)
  ) agents;
  wrappers = pkgs.lib.attrValues wrappersByName;

  # Derive the launcher's `new <agent>` dispatch from wrappersByName so adding an
  # agent to `agents` above auto-extends the launcher — no hardcoded claude|codex|
  # pi arms to drift out of sync. agentNames feeds the usage/error messages.
  agentNames = pkgs.lib.concatStringsSep "|" (builtins.attrNames agents);
  agentArms = pkgs.lib.concatStringsSep "\n" (
    pkgs.lib.mapAttrsToList (
      name: w: "            ${name}) bin=${w}/bin/jailed-${name} ;;"
    ) wrappersByName
  );

  # Manage per-feature jj workspaces for jailed agents. Subcommands:
  #   jailed-agent-ws new <agent> <feature> [agent args...]   (agent ∈ agents)
  #       create (or reuse) a sibling workspace <repo>-<feature>, activate its
  #       own devenv via direnv (built on the host), then launch the jailed agent
  #   jailed-agent-ws rm <feature> [--force]
  #       forget the workspace and delete its dir. Refuses if the workspace head
  #       isn't reachable from a bookmark or a remote bookmark (i.e. unsaved
  #       work), unless --force. Commits stay in the op log regardless.
  #   jailed-agent-ws ls
  #       list workspaces and their on-disk dirs
  launcher = pkgs.writeShellApplication {
    name = "jailed-agent-ws";
    runtimeInputs = with pkgs; [
      jujutsu
      direnv
      coreutils
      gnugrep
    ];
    text = ''
            # Resolve the MAIN repo root so subcommands work from any workspace (a
            # workspace's .jj/repo is a pointer file to <main>/.jj/repo).
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
                  echo "usage: jailed-agent-ws new <${agentNames}> <feature> [agent args...]" >&2
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
                # Activate the workspace's own devenv (builds on the host, where nix
                # works) then jail; the agent forwards the resulting env minus secrets.
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
                  echo "usage: jailed-agent-ws rm <feature> [--force]" >&2
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
                  # commits unique to this workspace's head that aren't reachable from
                  # any (local or remote) bookmark — i.e. work that only lives here.
                  # Fail CLOSED: if jj log errors (locked repo, bad head, …) we must not
                  # fall through to rm -rf and lose the working copy. --force overrides.
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
                echo "usage: jailed-agent-ws <new|rm|ls> ..." >&2
                echo "  new <${agentNames}> <feature> [args...]  create/enter a jailed agent workspace" >&2
                echo "  rm  <feature> [--force]                    forget the workspace and remove its dir" >&2
                echo "  ls                                         list workspaces and their dirs" >&2
                exit 2
                ;;
            esac
    '';
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
    ;
}
