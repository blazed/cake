{ adminUser, ... }:
{
  home-manager = {
    users.${adminUser.name} = {
      home.username = "${adminUser.name}";
      inherit (adminUser) userinfo;
      programs = {
        git = {
          extraConfig = {
            gpg.format = "ssh";
            commit.gpgSign = true;
            tag.forceSignAnnotated = true;
          };
        };
      };
    };
  };
}
