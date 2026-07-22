{
  adminUser,
  hostName,
  inputs,
  ...
}:
{
  home-manager.extraSpecialArgs = { inherit hostName inputs adminUser; };
  home-manager.sharedModules = [
    ../users/modules/theme.nix
    ../users/modules/userinfo.nix
    inputs.dms.homeModules.dank-material-shell
    inputs.niri.homeModules.niri
  ];
}
