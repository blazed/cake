{
  inputs,
  lib,
  ...
}: let
  inherit (lib) genAttrs;
  inherit (builtins) filter pathExists attrNames;

  pkgList =
    filter (elem: ! (inputs.${elem} ? "sourceInfo") && pathExists (toString (./. + "/${elem}"))) (attrNames inputs);
in
  (
    genAttrs pkgList (key: (final: prev: {${key} = prev.callPackage (./. + "/${key}") {inherit inputs;};}))
  )
  // {
    cake-updaters = import ./cake-updaters-overlay.nix;
    inputs = final: prev: {inherit inputs;};
    swaylock-dope = final: prev: {swaylock-dope = prev.callPackage ./swaylock-dope {};};
    netns-dbus-proxy = final: prev: {netns-dbus-proxy = prev.callPackage ./netns-dbus-proxy {};};
    scripts = final: prev: {scripts = prev.callPackage ./scripts {};};
  }
