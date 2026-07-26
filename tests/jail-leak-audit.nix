{ pkgs, inputs, ... }:
let
  builders = import ../users/profiles/jailed-agents-builders.nix { inherit pkgs inputs; };

  # Audit payload, wrapped in claude's *exact* sandbox permission set. Uses only
  # bash builtins + coreutils so it doesn't depend on the curated toolset (whose
  # presence/absence is itself checked). Exits non-zero on any leak.
  auditScript = pkgs.writeShellScript "leak-audit" ''
    set -u
    rc=0
    blocked() { # must NOT be reachable
      if ls -d "$1" >/dev/null 2>&1 || cat "$1" >/dev/null 2>&1; then
        echo "LEAK: $1 reachable"; rc=1
      else echo "ok:   $1 blocked"; fi
    }
    allowed() { # must be reachable
      if ls -d "$1" >/dev/null 2>&1; then echo "ok:   $1 reachable (intended)"
      else echo "MISSING: $1 not reachable"; rc=1; fi
    }

    echo "## HOME=$HOME ; ls ~ ->"; ls -a1 "$HOME"

    echo "## secrets that must be blocked"
    for p in .ssh .aws .gnupg .kube .config/gcloud .codex .pi code; do
      blocked "$HOME/$p"
    done
    blocked /run/agenix/fake-key
    blocked /etc/shadow

    echo "## paths the agent should reach"
    allowed "$HOME/.claude"
    allowed "$HOME/.claude.json"
    allowed "$HOME/.config/git/ignore"
    if [ "$(cat "$HOME/.config/git/ignore")" = '*.global-ignore' ]; then
      echo "ok:   global Git ignore mounted"
    else
      echo "MISSING: global Git ignore content"; rc=1
    fi
    if echo MUTATION >> "$HOME/.config/git/ignore" 2>/dev/null; then
      echo "LEAK: global Git ignore is writable"; rc=1
    else
      echo "ok:   global Git ignore is read-only"
    fi
    if [ -e ./LEAK_MARKER.txt ]; then echo "ok:   CWD mounted"; else echo "MISSING: cwd marker"; rc=1; fi

    echo "## environment: secret-looking vars stripped, benign project vars forwarded"
    # DATABASE_URL embeds user:pass@ in its value, so it must be stripped by value
    # even though its name matches no deny pattern.
    for v in AWS_SECRET_ACCESS_KEY GITHUB_TOKEN DB_PASSWORD MYSQL_PWD DATABASE_URL MY_API_KEY PROTON_PASS_PERSONAL_ACCESS_TOKEN SSH_AUTH_SOCK; do
      if [ -n "''${!v:-}" ]; then echo "LEAK: secret env $v present"; rc=1; else echo "ok:   secret env $v stripped"; fi
    done
    if [ "''${PROJECT_SETTING:-}" = "ok" ]; then echo "ok:   benign env PROJECT_SETTING forwarded"; else echo "MISSING: PROJECT_SETTING not forwarded"; rc=1; fi
    # A credential-free URL must NOT be stripped (value-based rule needs :pass@).
    if [ "''${SERVICE_URL:-}" = "http://localhost:9292" ]; then echo "ok:   credential-free SERVICE_URL forwarded"; else echo "MISSING: SERVICE_URL stripped/absent"; rc=1; fi

    echo "## process namespace isolation"
    set -- /proc/[0-9]*
    echo "visible PIDs: $#"
    if [ "$#" -lt 20 ]; then echo "ok:   pid namespace isolated"; else echo "LEAK: $# PIDs visible"; rc=1; fi

    echo
    if [ "$rc" -eq 0 ]; then echo "RESULT: NO LEAKS"; else echo "RESULT: LEAKS DETECTED"; fi
    exit "$rc"
  '';

  passAuditScript = pkgs.writeShellScript "pass-audit" ''
    set -eu
    command -v pass-cli >/dev/null
    [ "$PROTON_PASS_KEY_PROVIDER" = fs ]
    [ "$PROTON_PASS_SESSION_DIR" = /tmp/pass-agent-pi ]
    [ "$PROTON_PASS_PERSONAL_ACCESS_TOKEN" = TEST_AGENT_TOKEN ]
    mkdir -p "$PROTON_PASS_SESSION_DIR"
    [ -w "$PROTON_PASS_SESSION_DIR" ]
    if cat /run/agenix/proton-pass-agent-token >/dev/null 2>&1; then
      echo "LEAK: Proton Pass token file reachable" >&2
      exit 1
    fi
    echo "RESULT: PASS CLI ISOLATED"
  '';
  auditJail = builders.jail "leak-audit" "${auditScript}" (builders.permsFor builders.agents.claude);
  passAuditJail = builders.jail "pass-audit" "${passAuditScript}" (
    builders.permsFor builders.agents.pi
  );
in
pkgs.testers.runNixOSTest {
  name = "jail-leak-audit";

  nodes.machine = {
    environment.systemPackages = [
      auditJail
      passAuditJail
      pkgs.bubblewrap
    ];
    users.users.tester = {
      isNormalUser = true;
      home = "/home/tester";
    };
  };

  testScript = ''
    machine.wait_for_unit("multi-user.target")

    # Secrets remain outside the sandbox. Pi receives only the explicitly injected
    # Proton Pass token value, while Claude receives neither file nor environment value.
    machine.succeed(
        "mkdir -p /run/agenix; "
        "echo SENTINEL > /run/agenix/fake-key; "
        "echo -n TEST_AGENT_TOKEN > /run/agenix/proton-pass-agent-token; "
        "chmod 644 /run/agenix/fake-key; "
        "chown tester:users /run/agenix/proton-pass-agent-token; "
        "chmod 600 /run/agenix/proton-pass-agent-token"
    )

    # Plant real secrets + the allowed config dirs as the tester user.
    machine.succeed(
        "su - tester -c 'umask 077; "
        "mkdir -p ~/.ssh ~/.aws ~/.gnupg ~/.kube ~/.config/gcloud ~/.config/git ~/.codex ~/.pi ~/code ~/.claude ~/work; "
        "echo \"*.global-ignore\" > ~/.config/git/ignore; "
        "echo PRIVKEY > ~/.ssh/id_ed25519; "
        "echo CREDS > ~/.aws/credentials; "
        "echo {} > ~/.claude.json; "
        "echo allowed > ~/.claude/settings.json; "
        "echo MARKER > ~/work/LEAK_MARKER.txt'"
    )

    with subtest("test data is genuinely readable on the host (so blocking is meaningful)"):
        machine.succeed("su - tester -c 'cat ~/.ssh/id_ed25519'")
        machine.succeed("su - tester -c 'cat /run/agenix/fake-key'")

    with subtest("jailed agent sandbox leaks nothing"):
        out = machine.succeed(
            "su - tester -c 'cd ~/work && "
            "AWS_SECRET_ACCESS_KEY=should-not-leak GITHUB_TOKEN=ghp_x DB_PASSWORD=hunter2 "
            "PROTON_PASS_PERSONAL_ACCESS_TOKEN=host-token-must-not-leak "
            "MYSQL_PWD=hunter2 DATABASE_URL=postgres://u:p@h/db SERVICE_URL=http://localhost:9292 "
            "MY_API_KEY=sk-x SSH_AUTH_SOCK=/run/user/0/keyring/ssh "
            "PROJECT_SETTING=ok TERM=xterm "
            "leak-audit'"
        )
        print(out)
        assert "RESULT: NO LEAKS" in out, out

    with subtest("jailed Pi receives only isolated Proton Pass configuration"):
        out = machine.succeed("su - tester -c 'cd ~/work && TERM=xterm pass-audit'")
        print(out)
        assert "RESULT: PASS CLI ISOLATED" in out, out
  '';
}
