{ pkgs, ... }:
{
  home = {
    packages = [ pkgs.proton-pass-cli ];

    sessionVariables = {
      PROTON_PASS_KEY_PROVIDER = "keyring";
      PROTON_PASS_LINUX_KEYRING = "dbus";
    };
  };
}
