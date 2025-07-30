{
  hostName,
  inputs,
  ...
}:
{
  home-manager.extraSpecialArgs = { inherit hostName inputs; };
  home-manager.sharedModules = [
    ../users/modules/theme.nix
    ../users/modules/userinfo.nix
  ];
}
