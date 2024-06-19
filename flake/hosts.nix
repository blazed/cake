{
  inputs,
  self,
  withSystem,
  ...
}: let
  inherit
    (inputs.nixpkgs.lib // builtins)
    filterAttrs
    foldl'
    makeOverridable
    mapAttrs'
    mapAttrsToList
    mkForce
    mkIf
    nixosSystem
    readDir
    replaceStrings
    substring
    ;

  nixSettings = {
    nix.registry.nixpkgs = {flake = inputs.nixpkgs;};
    nix.registry.cake = {flake = inputs.self;};
  };
  mapSystems = dir: mapAttrsToList (name: _: name) (filterAttrs (_: type: type == "directory") (readDir dir));
  mapHosts = foldl' (
    hosts: system:
      hosts
      // (mapAttrs' (
        filename: _: let
          name = replaceStrings [".nix"] [""] filename;
        in {
          inherit name;
          value = {
            inherit system;
            hostconf = ../hosts + "/${system}/${filename}";
          };
        }
      ) (builtins.readDir ../hosts/${system}))
  ) {};

  defaultModules = [
    nixSettings
    inputs.agenix.nixosModules.age
    inputs.disko.nixosModules.disko
    inputs.home-manager.nixosModules.home-manager
    inputs.impermanence.nixosModules.impermanence
    inputs.nixpkgs.nixosModules.notDetected
    ../modules/default.nix
  ];

  nixosConfigurations = mapAttrs' (
    name: conf: let
      inherit (conf) system hostconf;
      adminUser = {
        name = "blazed";
        uid = 1447;
        gid = 1447;
        userinfo = {
          email = "blazed@darkstar.se";
          fullName = "Pierre Boberg";
          githubUser = "blazed";
        };
      };
    in {
      inherit name;
      value = withSystem system ({pkgs, ...}:
        makeOverridable nixosSystem {
          inherit system;
          specialArgs = {
            hostName = name;
            tailnet = "tailef5cf";
            inherit adminUser;
            hostConfigurations =
              mapAttrs' (name: conf: {
                inherit name;
                value = conf.config;
              })
              nixosConfigurations;
            inherit inputs;
          };
          modules =
            [
              {
                inherit adminUser;
              }
              {
                system.configurationRevision = mkIf (self ? rev) self.rev;
                system.nixos.versionSuffix = mkForce "git.${substring 0 11 inputs.nixpkgs.rev}";
                nixpkgs.pkgs = pkgs;
                environment.systemPackages = [
                  pkgs.cake
                ];
              }
            ]
            ++ defaultModules
            ++ [
              hostconf
            ];
        });
    }
  ) (mapHosts (mapSystems ../hosts));
in {
  flake = {
    inherit nixosConfigurations;
  };
}
