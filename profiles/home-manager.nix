{ hostName, config, ... }:
let
  inherit (builtins) mapAttrs;
in
{
  hame-manager.users = mapAttrs (user: conf:
    { ... }:
    {
      imports = [
        ../users/profiles/home.nix
        ../users/profiles/extra-config.nix
      ]++ conf.profiles;

      home.username = user;
      home.extraConfig.hostName = hostName;
      home.extraConfig.userEmail = conf.email;
      home.extraConfig.userFullName = conf.fullName;
      home.extraConfig.gitHubUser = conf.gitHubUser;
    }
  ) config.userConfiguration;
}
