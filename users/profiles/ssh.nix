{
  programs.ssh = {
    enable = true;
    forwardAgent = false;
    serverAliveInterval = 60;
    controlMaster = "auto";
    controlPersist = "30m";
    matchBlocks = {
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
