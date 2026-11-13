{
  withSystem,
  lib,
  self,
  ...
}:
let
  inherit (lib)
    attrNames
    mapAttrsToList
    filterAttrs
    hasPrefix
    filter
    elem
    ;
  defaultSkip = [
    "container-"
    "container-processes"
    "container-shell"
    "devenv-up"
  ];
  # These workstation hosts currently exceed GitHub-hosted runner limits when
  # building from a cold cache. Keep lighter host builds enabled, and cache the
  # agent packages through the package matrix instead.
  hostSkip = [
    "amelia"
    "diana"
    "nicolina"
  ];
in
{
  flake = {
    github-actions-package-matrix-x86-64-linux = withSystem "x86_64-linux" (
      ctx@{ pkgs, ... }:
      let
        skip =
          (mapAttrsToList (name: _: name) (filterAttrs (name: _: hasPrefix "images/" name) pkgs))
          ++ defaultSkip;
      in
      {
        os = [ "ubuntu-latest" ];
        pkg = filter (item: !(elem item skip)) (mapAttrsToList (name: _: name) ctx.config.packages);
      }
    );

    github-actions-package-matrix-aarch64-linux = withSystem "aarch64-linux" (
      ctx@{ pkgs, ... }:
      let
        skip =
          (mapAttrsToList (name: _: name) (filterAttrs (name: _: hasPrefix "images/" name) pkgs))
          ++ defaultSkip
          ++ [
            "wezterm"
          ];
      in
      {
        os = [ "ubuntu-latest" ];
        pkg = filter (item: !(elem item skip)) (mapAttrsToList (name: _: name) ctx.config.packages);
      }
    );

    # The router test has its own job, which retries it.
    github-actions-check-matrix-x86-64-linux = withSystem "x86_64-linux" (ctx: {
      os = [ "ubuntu-latest" ];
      check = filter (name: name != "router") (attrNames ctx.config.checks);
    });

    github-actions-host-matrix-x86-64-linux = {
      os = [ "ubuntu-latest" ];
      host = mapAttrsToList (name: _: name) (
        filterAttrs (
          name: config: config.pkgs.system == "x86_64-linux" && !(elem name hostSkip)
        ) self.nixosConfigurations
      );
    };

    github-actions-host-matrix-aarch64-linux = {
      os = [ "ubuntu-latest" ];
      host = mapAttrsToList (name: _: name) (
        filterAttrs (_: config: config.pkgs.system == "aarch64-linux") self.nixosConfigurations
      );
    };
  };
}
