{ pkgs, inputs, ... }:
let
  builders = import ../users/profiles/jailed-agents-builders.nix { inherit pkgs inputs; };

  # Probe wrapped in claude's exact sandbox (which includes the jjWorkspace
  # combinator). Run from inside a jj workspace, it must be able to drive jj
  # against the shared store while NOT seeing a sibling workspace's working tree
  # or the (signing-enabled) user jj config.
  probe = builders.jail "jj-probe" "${pkgs.writeShellScript "jj-probe-script" ''
    echo "JJ_USER=$JJ_USER JJ_EMAIL=$JJ_EMAIL"
    echo "JJ_EDITOR=$JJ_EDITOR"
    jj describe -m "from jail" 2>&1 | head -3
    # editor-driven (no -m): must NOT hang on an interactive editor. JJ_EDITOR=echo
    # makes jj reuse the existing description. timeout guards against a regression.
    timeout 20 jj describe 2>&1 | head -2 && echo DESCRIBE_NOEDITOR_OK || echo DESCRIBE_NOEDITOR_HANG
    jj --ignore-working-copy log --no-graph -r '@' 2>&1 | head -2
    cat ./FEATURE.txt >/dev/null 2>&1 && echo FEATURE_OK || echo FEATURE_MISSING
    if cat "$HOME/proj/MAIN_SECRET.txt" >/dev/null 2>&1; then echo MAIN_LEAK; else echo MAIN_BLOCKED; fi
    if cat "$HOME/.config/jj/config.toml" >/dev/null 2>&1; then echo CONFIG_LEAK; else echo CONFIG_NOT_BOUND; fi
  ''}" (builders.permsFor builders.agents.claude);
in
pkgs.testers.runNixOSTest {
  name = "jail-jj-workspace";

  nodes.machine = {
    environment.systemPackages = [
      probe
      pkgs.jujutsu
    ];
    users.users.tester = {
      isNormalUser = true;
      home = "/home/tester";
    };
  };

  testScript = ''
    machine.wait_for_unit("multi-user.target")

    # jj identity in the user config (no signing yet, so the host setup commits
    # below can be created — the VM has no ssh signing key).
    machine.succeed(
        "su - tester -c 'mkdir -p ~/.config/jj && "
        "printf \"[user]\\nname = \\\"Tester\\\"\\nemail = \\\"tester@example.com\\\"\\n\" "
        "> ~/.config/jj/config.toml'"
    )

    # colocated repo with a secret working file in main + a second workspace.
    machine.succeed(
        "su - tester -c 'mkdir ~/proj && cd ~/proj && jj git init --colocate && "
        "echo secret-in-main > MAIN_SECRET.txt && jj describe -m init && jj new -m wip && "
        "jj workspace add --name feat ~/proj-feat && echo feature > ~/proj-feat/FEATURE.txt'"
    )

    # NOW enable ssh signing in the user config. With no key on the VM this would
    # make any host-side commit fail — which is exactly the point: the jail must
    # neither bind this config nor attempt signing.
    machine.succeed(
        "su - tester -c 'printf \"[signing]\\nbehavior = \\\"own\\\"\\nbackend = \\\"ssh\\\"\\n\" "
        ">> ~/.config/jj/config.toml'"
    )

    with subtest("jj works in-jail from a workspace; identity injected; isolation holds"):
        # forward a bogus interactive JJ_EDITOR — the jail must override it with echo.
        out = machine.succeed("su - tester -c 'cd ~/proj-feat && TERM=xterm JJ_EDITOR=nano jj-probe'")
        print(out)
        assert "from jail" in out, out                 # jj describe succeeded (unsigned)
        assert "tester@example.com" in out, out         # identity injected via JJ_EMAIL
        assert "Signing error" not in out, out          # signing not attempted in jail
        assert "JJ_EDITOR=echo" in out, out             # editor forced to no-op, beats forwarded nano
        assert "DESCRIBE_NOEDITOR_OK" in out and "DESCRIBE_NOEDITOR_HANG" not in out, out  # no interactive hang
        assert "FEATURE_OK" in out, out                 # own workspace files reachable
        assert "MAIN_BLOCKED" in out and "MAIN_LEAK" not in out, out   # sibling tree hidden
        assert "CONFIG_NOT_BOUND" in out and "CONFIG_LEAK" not in out, out  # jj config not bound
  '';
}
