{
  pkgs,
  lib,
  config,
  ...
}: let
  inherit (config) home;
  nu-scripts = "${pkgs.nu_scripts}/share/nu_scripts";
in {
  programs.atuin.enable = true;
  programs.atuin.enableNushellIntegration = true;
  programs.direnv.enableNushellIntegration = false;
  programs.zoxide.enable = true;
  programs.zoxide.enableNushellIntegration = true;
  programs.nushell = {
    enable = true;
    package = pkgs.nushell;
    configFile.source = ./config.nu;
    envFile.source = ./env.nu;
    extraConfig = ''
      source ~/.config/nushell/home.nu
      source ~/.config/nushell/starship.nu

      $env.config.hooks.pre_prompt = (
        $env.config.hooks.pre_prompt | append (source ${nu-scripts}/nu-hooks/nu-hooks/direnv/config.nu)
      )

      ${
        lib.concatStringsSep "\n"
        (
          map (completion: "use ${nu-scripts}/custom-completions/${completion}/${completion}-completions.nu") [
            "cargo"
            "git"
            "just"
            "nix"
            "npm"
            "man"
            "make"
          ]
        )
      }
    '';
  };
  xdg.configFile."nushell/starship.nu".source = ./starship.nu;
  xdg.configFile."nushell/home.nu".source = pkgs.writeText "home.nu" ''
    ${
      lib.concatStringsSep "\n" (lib.mapAttrsToList (name: value: "$env.${name} = \"${value}\";") home.sessionVariables)
    }
  '';
}
