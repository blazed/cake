{
  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;

    matchBlocks = {
      "*" = {
        controlPersist = "30m";
        controlMaster = "auto";
        controlPath = "~/.ssh/master-%r@%n:%p";
        serverAliveInterval = 60;
        serverAliveCountMax = 3;
        hashKnownHosts = false;
        forwardAgent = true;
        addKeysToAgent = "no";
        compression = false;
      };
      "github github.com" = {
        hostname = "github.com";
        user = "git";
        forwardAgent = false;
        extraOptions = {
          preferredAuthentications = "publickey";
          controlMaster = "no";
          controlPath = "none";
        };
      };
      "git.exsules.com git.exsules.dev" = {
        user = "git";
        forwardAgent = false;
        extraOptions = {
          preferredAuthentications = "publickey";
          controlMaster = "no";
          controlPath = "none";
        };
      };
      "192.168.122.141" = {
        user = "kaziri";
        forwardAgent = false;
      };
      "nicolina" = {
        user = "blazed";
        forwardAgent = true;
      };
    };
  };
}
