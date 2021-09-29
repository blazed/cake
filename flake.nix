{
  description = "NixOS Configurations";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    nixos-hardware.url = "github:nixos/nixos-hardware";
    nur.url = "github:nix-community/NUR";
    fenix = {
      url = "github:nix-community/fenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-misc = {
      url = "github:johnae/nix-misc";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    packages = {
      url = "path:./packages";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.fenix.follows = "fenix";
      inputs.nix-misc.follows = "nix-misc";
    };
    agenix = {
      url = "github:ryantm/agenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, ...} @ inputs:
    let
      inherit (nixpkgs.lib) genAttrs filterAttrs mkOverride makeOverridable mkIf
        hasSuffix mapAttrs mapAttrs' removeSuffix nameValuePair nixosSystem
        mkForce mapAttrsToList splitString concatStringsSep last hasAttr;
      inherit (builtins) replaceStrings attrNames functionArgs substring pathExists fromTOML readFile readDir listToAttrs filter;

      supportedSystems = [ "x86_64-linux" ];
      forAllSystems = genAttrs supportedSystems;
      pkgs = forAllSystems (system: import nixpkgs {
        inherit system;
        config.allowUnfree = true;
        overlays = [
          inputs.nix-misc.overlay
          inputs.nur.overlay
          inputs.agenix.overlay
        ] ++ mapAttrsToList (_: value: value) inputs.packages.overlays;
      });

      hostConfigs = mapAttrs' (f: _:
        let hostname = replaceStrings [".toml"] [""] f;
        in { name = hostname; value = fromTOML (readFile (./hosts + "/${f}")); }
      ) (readDir ./hosts);

      hosts = mapAttrs (_: config:
        let
          profiles = config.profiles;
          cfg = builtins.removeAttrs config ["profiles"];
        in
        {
        specialArgs.hostConfig = cfg;
        specialArgs.hostConfigs = hostConfigs;
        configuration.imports = (map (item:
          if pathExists (toString (./. + "/${item}")) then
            (./. + "/${item}")
          else (./. + "/${item}.nix")
        ) profiles) ++ [ ./modules ./profiles/disable-users-groups-dry-run.nix ]; ## disable-users-groups-dry-run is a temp fix
      }) hostConfigs;

      toNixosConfig = hostName: host:
        let system = "x86_64-linux"; in
        makeOverridable nixosSystem {
          inherit system;
          specialArgs = {
            pkgs = pkgs.${system};
            inherit hostName inputs;
            userProfiles = import ./users/profiles.nix { lib = inputs.nixpkgs.lib; };
          } // host.specialArgs;
          modules = [
            { system.configurationRevision = mkIf (self ? rev) self.rev; }
            { system.nixos.versionSuffix = mkForce "git.${substring 0 11 nixpkgs.rev}"; }
            { nixpkgs = { pkgs = pkgs.${system}; }; }
            inputs.nixpkgs.nixosModules.notDetected
            inputs.home-manager.nixosModules.home-manager
            inputs.agenix.nixosModules.age
            host.configuration
          ];
        };

      toPxeBootSystemConfig = hostName:
        let
          system = "x86_64-linux";
          bootSystem = makeOverridable nixosSystem {
            inherit system;
            specialArgs = {
              pkgs = pkgs.${system};
              inherit hostName inputs;
            };
            modules = [
              { system.configurationRevision = mkIf (self ? rev) self.rev; }
              { system.nixos.versionSuffix = mkForce "git.${substring 0 11 nixpkgs.rev}"; }
              { nixpkgs = { pkgs = pkgs.${system}; }; }
              inputs.nixpkgs.nixosModules.notDetected
              ({ modulesPath, pkgs, ... }: {
                 imports = [
                   "${modulesPath}/installer/netboot/netboot-minimal.nix"
                   ./cachix.nix
                 ];
                 nix = {
                   trustedUsers = [ "root" ];
                   extraOptions = ''
                     experimental-features = nix-command flakes ca-references
                   '';
                   package = pkgs.nixUnstable;
                 };
                 environment.systemPackages = with pkgs; [
                   git curl jq skim
                 ];
                 boot.zfs.enableUnstable = true;
                 boot.kernelPackages = pkgs.linuxPackages_latest;
                 services.getty.autologinUser = mkForce "root";
                 hardware.video.hidpi.enable = true;
                 # Enable sshd which gets disabled by netboot-minimal.nix
                 systemd.services.sshd.wantedBy = mkOverride 0 [ "multi-user.target" ];
                 users.users.root.openssh.authorizedKeys.keys = [
                   "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQC7jrwDFcxP329CNp2kUlGH3cvvrY5DHTJdB6ZsjhpnK1yEVpRrG87TOkxrdBOX+s8bVL/8vR3xgvkaKl67zav9JG1xk9HOYKnAHJ7laLX0WJSHsdL9MHblUbVHnn7rXXQvzwmTUacQlF8h8LiTfGAcSNmj9hrehOzkU1v+mpeOsga7yAMuJWI1Tb7AJ+gzHO/72dEeA5VG0JC43KGMW4yYd12pG/58d9RkaT0Et/rXK7zpYhzaPSl1JlCxYYl12OcjQCoWTz5Bq5jS2cW5dup6/N6kuGdanTGxI4yUIWlUyLPjHUZ5g7EcyBuAE2/v33QUFiwhQjNvHdvhoaoil/T1hye2YJfZ6i+ghrN+jW4Prw2znZ+txRhFlIIXmeEMCBN4aLx5oTWH6qXHRGYjCSPhoU+P8jcagBKTApC0gzNK8jH4nJ8VhGs+g+N2337u5pjjCy9IAN9E8wiODgAvsButF+dFkHXEEzJ9pOrin4/MFUpVQklFwVTTCYP2mXa66zkI+JqoTNCkY5uJPxraxKdq0+0aWjh3KApr5vGA6ZFbkHX3tZdOAWTFZkM46Z3ZxohzWJfJg+eLyAmBbRjJjYU6X5lvb697aksAaqjV2NlkEBxmQTFf9QgrrzfTQubP1Nxj1wnrJd/ytofMIiVMVZ5JLAVIatetV9ZICmxF4j6Tiw=="
                   "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDDd9ZjCyGAjtjM6lCVZ46+c3PZvYDzFxECpa3NRwZG8zGnPcbIsFIyQzOdk0eywHFZikNeTxxxiDYXeTnuHuMkweVw5mYIwb8hXj8ts7qoCOVJP9P+KnnEb4WS/edG+Arv1nVeNIXswjHKjOtUSRtoNlRuY0x4kyF9EAbVTrHrB5HDtr7GTGQAGAEp33jQqHrIqFoWmNm9GQ3jqP0b4AcZVRXjAj+amqUQ2+gRt4r1r1kzLuvmOrTbOxnNB/N2hGNCkTbIqP1tDVq03EY0ISOWG+1+TW79ASkSYIdnmQBoB+x6Eh+9CGe65wjM0Op3Q564ZS3Qde1GzMchx5A4W7rrMAOzLXJaQ8Mi7gjsDjrqxBfDDXUU5JL5xn0PhhI1teXvQ5aR90cSs424PS3Yrbqs/pHsybcB/kh25MlO9rGXA9MHh7LlVCPIvus/SDopVgTgNIvhYbQh9xdogkG1XdkvyzXmvAJ6Gk/TR/KRWURwQyp1WJxJ8nHr/zUWrU55zXrN/5gWbDB5k9zuR5G4EGrZshM3EuNeQtjMlHcLWfoZuwaOmar/NOmaXzrBCZb/jXNhQkh6M94krXWE0DIkwsu+5n14llMo/OCxneIEqx4FqZePC8x8qpqfKRzSetOG5PVdCO/8w1erhkg8uETguiPTK4uCfCgtZ75ISpv+7nEwuQ=="
                   "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIA0LuxetOJ9SPC0v/icZQxL1+8c58y8I4pp0eb0U8ecQ"
                 ];

                 environment.etc."profile.local".text = ''
                   attempt=0
                   max_attempts=5
                   wait_secs=3
                   while ! curl -sf --connect-timeout 5 --max-time 5 http://www.google.com > /dev/null; do
                     if [ "$attempt" -ge "$max_attempts" ]; then
                       echo Fail - no internet, tried "$max_attempts" times over $((max_attempts * wait_secs)) seconds
                       exit 1
                     fi
                     sleep "$wait_secs"
                   done
                   if [ -z "$_INSTALLER_HAS_RUN" ]; then
                     _INSTALLER_HAS_RUN=y
                     export _INSTALLER_HAS_RUN
                     git clone https://github.com/blazed/cake /tmp/cake
                     cd /tmp/cake
                     echo 'Which config should be installed?'
                     host="$(nix eval --apply builtins.attrNames .#nixosConfigurations --json | jq -r '.[]' | sk)"
                     nix build .#"$host"-diskformat
                     ./result/bin/diskformat | tee -a diskformat.log
                     mount
                     nixos-install --flake .#"$host" --no-root-passwd --impure | tee -a nixos-install.log
                   else
                     echo installer has already been run
                   fi
                   bash
                 '';
              })
            ];
          };
          in
           pkgs.${system}.symlinkJoin {
             name = "netboot";
             paths = with bootSystem.config.system.build; [
               netbootRamdisk
               kernel
               netbootIpxeScript
             ];
             preferLocalBuild = true;
          };

      toDiskFormatter = hostName: config:
        inputs.nixpkgs.lib.nameValuePair "${hostName}-diskformat" (
          pkgs.x86_64-linux.callPackage ./utils/diskformat.nix {
            inherit hostName config;
          }
        );

      cakeUtils = let
        f = import ./utils/cake.nix;
        args = listToAttrs (map (name: { inherit name; value = pkgs.x86_64-linux.${name}; }) (attrNames (functionArgs f)));
      in f args;

      hostConfigurations = mapAttrs toNixosConfig hosts;

      nixosConfigurations = hostConfigurations;

      diskFormatters = mapAttrs' toDiskFormatter hostConfigurations;
      exportedPackages = (mapAttrs (name: _: pkgs.x86_64-linux.${name}) (filterAttrs (name: _: (hasAttr name pkgs.x86_64-linux) && nixpkgs.lib.isDerivation pkgs.x86_64-linux.${name}) inputs.packages.overlays)) // { pxebooter = toPxeBootSystemConfig "pxebooter"; };

    in
    {
      devShell = forAllSystems (system:
        pkgs.${system}.callPackage ./devshell.nix {
          inherit cakeUtils;
          agenix = pkgs.${system}.agenix.override { nix = pkgs.${system}.nixUnstable; };
          mkDevShell = pkgs.${system}.callPackage inputs.nix-misc.lib.mkSimpleShell { };
        }
      );

      inherit nixosConfigurations hostConfigs;

      packages.x86_64-linux = diskFormatters // exportedPackages // cakeUtils;

      github-actions-package-matrix = {
        os = [ "ubuntu-latest" ];
        pkg = mapAttrsToList (name: _:  name) exportedPackages;
      };

      github-actions-host-matrix = {
        os = [ "ubuntu-latest" ];
        host = mapAttrsToList (name: _:  name) nixosConfigurations;
      };
  };
}
