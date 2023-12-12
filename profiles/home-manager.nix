{
  hostName,
  userProfiles,
  ...
}: let
  inherit (builtins) mapAttrs;
in {
  home-manager.extraSpecialArgs = {inherit hostName;};
  home-manager.sharedModules = [
    ../users/modules/theme.nix
    ../users/modules/userinfo.nix
  ];
  home-manager.users =
    mapAttrs (
      user: profiles: {...}: {
        imports = [../users/profiles/home.nix] ++ profiles;
        home.username = user;
      }
    )
    userProfiles;
}
