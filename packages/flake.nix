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

    ## non flakes
    age-plugin-yubikey = { url = "github:str4d/age-plugin-yubikey"; flake = false; };
    fish-kubectl-completions = { url = "github:evanlucas/fish-kubectl-completions"; flake = false; };
    google-cloud-sdk-fish-completion = { url = "github:Doctusoft/google-cloud-sdk-fish-completion"; flake = false; };
    nixpkgs-fmt = { url = "github:nix-community/nixpkgs-fmt"; flake = false; };
    netns-exec = { url = "github:johnae/netns-exec"; flake = false; };
  };

  outputs = { self, nixpkgs, ...} @ inputs:
    let
      inherit (nixpkgs.lib) genAttrs listToAttrs mapAttrsToList filterAttrs;
      inherit (builtins) filter attrNames pathExists toString mapAttrs hasAttr;
      supportedSystems = [ "x86_64-linux" ];
      forAllSystems = genAttrs supportedSystems;
      pkgs = forAllSystems (system: import nixpkgs {
        inherit system;
        overlays = mapAttrsToList (_: value: value) self.overlays;
      });
      extraPkgs = [ "k3s-io" ];
      nonFlakePkgList = (filter (elem: ! (inputs.${elem} ? "sourceInfo") && pathExists (toString (./. + "/${elem}"))) (attrNames inputs)) ++ extraPkgs;
      exportedPackages = mapAttrs (name: _: pkgs.x86_64-linux.${name}) (filterAttrs (name: _: (hasAttr name pkgs.x86_64-linux) && nixpkgs.lib.isDerivation pkgs.x86_64-linux.${name}) self.overlays);
    in
    {
      overlays = (
        mapAttrs (_: value: value.overlay) (filterAttrs (_: v: v ? "overlay") inputs)
      )
      //
      (genAttrs nonFlakePkgList (key: (
        (final: prev: { ${key} = prev.callPackage (./. + "/${key}") { }; })
      )))
      //
      {
        nixos-generators = (final: prev: { inherit (inputs.nixos-generators.packages.${prev.system}) nixos-generators; });
        inputs = (final: prev: { inherit inputs; });
        my-neovim-config = (final: prev: { my-emacs-config = prev.callPackage ./my-neovim/config.nix { }; });
        scripts = (final: prev: { scripts = prev.callPackage ./scripts { }; });
      };
     packages.x86_64-linux = exportedPackages;
     devShell = forAllSystems (system:
       pkgs.${system}.callPackage ./devshell.nix {
         mkDevShell = pkgs.${system}.callPackage inputs.nix-misc.lib.mkSimpleShell {};
       }
     );
    };
}
