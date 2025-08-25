{
  programs.ssh = {
    enable = true;
    matchBlocks = {
      "*" = {
        controlPersist = "30m";
        controlMaster = "auto";
        serverAliveInterval = 60;
        forwardAgent = false;
      };
      "github github.com" = {
        hostname = "github.com";
        user = "git";
        forwardAgent = false;
        extraOptions = {
          preferredAuthentications = "publickey";
        };
      };
      "nicolina" = {
        user = "blazed";
        forwardAgent = true;
      };
    };
  };
}
