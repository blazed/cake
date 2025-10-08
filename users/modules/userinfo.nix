{ lib, ... }:
{
  options = with lib; {
    userinfo = {
      fullName = mkOption {
        type = types.str;
        example = "Björn Dog";
      };
      email = mkOption {
        type = types.str;
        example = "bjorn@dog.com";
      };
      githubUser = mkOption {
        type = types.str;
        example = "bjorn";
      };
      githubEmail = mkOption {
        type = types.str;
        example = "bjorn@users.noreply.github.com";
      };
    };
  };
}
