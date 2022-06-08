{lib, ...}: {
  options.home.extraConfig = {
    hostName =
      lib.mkOption
      {
        type = lib.types.str;
        example = "hostname";
      };
    userFullName =
      lib.mkOption
      {
        type = lib.types.str;
        example = "Some name";
      };
    userEmail =
      lib.mkOption
      {
        type = lib.types.str;
        example = "email@example.org";
      };
    gitHubUser =
      lib.mkOption
      {
        type = lib.types.str;
        example = "handle";
      };
  };
}
