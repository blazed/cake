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
    wayland-protocols-master = final: prev: {wayland-protocols-master = prev.callPackage ./wayland-protocols-master {};};
  }
  // {
    cake-updaters = import ./cake-updaters-overlay.nix;
    wlroots-master = final: prev: {
      wlroots-master = prev.callPackage ./wlroots-master {
        wayland-protocols = final.wayland-protocols-master;
      };
    };
    sway-unwrapped = final: prev: {
      sway-unwrapped = prev.callPackage ./sway {
        wlroots = final.wlroots-master;
        wayland-protocols = final.wayland-protocols-master;
      };
    };
    sway = final: prev: {sway = prev.callPackage (prev.path + "/pkgs/applications/window-managers/sway/wrapper.nix") {};};
    swayidle = final: prev: {
      swayidle = prev.callPackage ./swayidle {
        wayland-protocols = final.wayland-protocols-master;
      };
    };
    inputs = final: prev: {inherit inputs;};
    swaylock-dope = final: prev: {swaylock-dope = prev.callPackage ./swaylock-dope {};};
    wl-clipboard-x11 = final: prev: {wl-clipboard-x11 = prev.callPackage ./wl-clipboard-x11 {};};
    rust-analyzer-bin = final: prev: {rust-analyzer-bin = prev.callPackage ./wl-clipboard-x11 {};};
    netns-dbus-proxy = final: prev: {netns-dbus-proxy = prev.callPackage ./netns-dbus-proxy {};};
    scripts = final: prev: {scripts = prev.callPackage ./scripts {};};
  }
