let
  # Shared policy for git forges: key-only auth, no connection multiplexing.
  gitForge = {
    User = "git";
    ForwardAgent = false;
    PreferredAuthentications = "publickey";
    ControlMaster = "no";
    ControlPath = "none";
  };
in
{
  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;

    settings = {
      "*" = {
        ControlPersist = "30m";
        ControlMaster = "auto";
        ControlPath = "~/.ssh/master-%r@%n:%p";
        ServerAliveInterval = 60;
        ServerAliveCountMax = 3;
        HashKnownHosts = false;
        ForwardAgent = true;
        AddKeysToAgent = "no";
        Compression = false;
      };
      "github github.com" = gitForge // {
        HostName = "github.com";
      };
      "git.exsules.com exsules.dev" = gitForge;
      "192.168.122.141" = {
        User = "kaziri";
        ForwardAgent = false;
      };
      "nicolina" = {
        User = "blazed";
        ForwardAgent = true;
      };
    };
  };
}
