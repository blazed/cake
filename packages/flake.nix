{
  description = "Packages";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    fenix = {
      url = "github:nix-community/fenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-misc = {
      url = "github:johnae/nix-misc";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    neovim-nightly-overlay =  {
      url = "github:nix-community/neovim-nightly-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixos-generators = {
      url = "github:nix-community/nixos-generators";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    devshell.url = "github:johnae/devshell";

    ## non flakes
    age-plugin-yubikey = { url = "github:str4d/age-plugin-yubikey"; flake = false; };
    blur = { url = "github:johnae/blur"; flake = false; };
    rofi-wayland = { url = "github:lbonn/rofi/wayland"; flake = false; };
    fish-kubectl-completions = { url = "github:evanlucas/fish-kubectl-completions"; flake = false; };
    google-cloud-sdk-fish-completion = { url = "github:Doctusoft/google-cloud-sdk-fish-completion"; flake = false; };
    nixpkgs-fmt = { url = "github:nix-community/nixpkgs-fmt"; flake = false; };
    netns-exec = { url = "github:johnae/netns-exec"; flake = false; };
    sway = { url = "github:swaywm/sway"; flake = false; };
    swayidle = { url = "github:swaywm/swayidle"; flake = false; };
    swaylock = { url = "github:swaywm/swaylock"; flake = false; };
    wayland-protocols-master = { url = "git+https://gitlab.freedesktop.org/wayland/wayland-protocols?ref=main"; flake = false; };
    wlroots = { url = "git+https://gitlab.freedesktop.org/wlroots/wlroots?ref=master"; flake = false; };
    wf-recorder = { url = "github:ammen99/wf-recorder"; flake = false; };
    wl-clipboard = { url = "github:bugaevc/wl-clipboard"; flake = false; };
  };

  outputs = { self, nixpkgs, ...} @ inputs:
    let
      inherit (nixpkgs.lib) genAttrs listToAttrs mapAttrsToList filterAttrs;
      inherit (builtins) filter attrNames pathExists toString mapAttrs hasAttr;

      overlays = mapAttrsToList (_: value: value) self.overlays;
      supportedSystems = [ "x86_64-linux" ];
      forAllSystems = f: genAttrs supportedSystems (system:
        f (import nixpkgs {
          inherit system overlays;
        })
      );

      extraPkgs = [ "meson-060" ];
      nonFlakePkgList = (filter (elem: ! (inputs.${elem} ? "sourceInfo") && pathExists (toString (./. + "/${elem}"))) (attrNames inputs)) ++ extraPkgs;
      exportedPackages = forAllSystems (pkgs:
        (mapAttrs (name: _: pkgs.${name})
          (filterAttrs (name: _: (hasAttr name pkgs) && nixpkgs.lib.isDerivation pkgs.${name}) self.overlays)
        )
      );
    in
    {
      overlays = (
        mapAttrs (_: value: value.overlay) (filterAttrs (_: v: v ? "overlay") inputs)
      )
      //
      (genAttrs nonFlakePkgList (key: (
        (final: prev: { ${key} = prev.callPackage (./. + "/${key}") { inherit inputs; }; })
      )))
      //
      {
        cake-updaters = import ./cake-updaters-overlay.nix;
        devshell = inputs.devshell.overlay;
        nixos-generators = (final: prev: { inherit (inputs.nixos-generators.packages.${prev.system}) nixos-generators; });
        wlroots = (final: prev: { wlroots = prev.callpackage ./wlroots { wayland-protocols = final.wayland-protocols-master; }; });
        sway-unwrapped = (final: prev: { sway-unwrapped = prev.callpackage ./sway { wayland-protocols = final.wayland-protocols-master; }; });
        sway = (final: prev: { sway = prev.callPackage (prev.path + "/pkgs/applications/window-managers/sway/wrapper.nix") { }; } );
        inputs = (final: prev: { inherit inputs; });
        my-neovim-config = (final: prev: { my-emacs-config = prev.callPackage ./my-neovim/config.nix { }; });
        swaylock-dope = (final: prev: { swaylock-dope = prev.callPackage ./swaylock-dope { }; });
        scripts = (final: prev: { scripts = prev.callPackage ./scripts { }; });
        wl-clipboard-x11 = (final: prev: { wl-clipboard-x11 = prev.callPackage ./wl-clipboard-x11 { }; });
        rust-analyzer-bin = (final: prev: { rust-analyzer-bin = prev.callPackage ./wl-clipboard-x11 { }; });
        netns-dbus-proxy = (final: prev: { netns-dbus-proxy = prev.callPackage ./wl-clipboard-x11 { }; });
      } //
      {
        wlroots = (final: prev: { wlroots = prev.callPackage ./wlroots { wayland-protocols = final.wayland-protocols-master; meson = prev.meson-060; }; });
        sway-unwrapped = (final: prev: { sway-unwrapped = prev.callPackage ./sway { wayland-protocols = final.wayland-protocols-master; meson = prev.meson-060; }; });
        swaylock = (final: prev: { swaylock = prev.callPackage ./swaylock { wayland-protocols = final.wayland-protocols-master; meson = prev.meson-060; }; });
      };
     packages = exportedPackages;
     devShell = forAllSystems (pkgs:
       pkgs.devshell.mkShell {
         imports = [
           (pkgs.devshell.importTOML ./devshell.toml)
         ];
       }
     );
    };
}
