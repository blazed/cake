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
    ++ forwardHostEnv c;

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
    };
  };

  wrappers = pkgs.lib.mapAttrsToList (
    name: spec: jail "jailed-${name}" spec.pkg (permsFor spec)
  ) agents;
in
{
  inherit
    jail
    agents
    permsFor
    wrappers
    ;
}
