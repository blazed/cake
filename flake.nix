{
  description = "NixOS Configurations";

  nixConfig = {
    extra-experimental-features = "nix-command flakes";
    extra-substituters = [
      "https://nix-community.cachix.org"
      "https://blazed.cachix.org"
      "https://cachix.cachix.org"
    ];
    extra-trusted-public-keys = [
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      "blazed.cachix.org-1:e9Rx3vtlQSp3nckCdGYpSFJbOb/hi1KuTyvWTBkiwAI="
      "cachix.cachix.org-1:eWNHQldwUO7G2VkjpnjDbWwy4KQ/HNxht7H4SSoMckM="
    ];
  };

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    nixos-hardware.url = "github:nixos/nixos-hardware";
    flake-utils.url = "github:numtide/flake-utils";
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
    agenix = {
      url = "github:ryantm/agenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    devshell.url = "github:numtide/devshell";
    devshell.inputs.flake-utils.follows = "flake-utils";
    devshell.inputs.nixpkgs.follows = "nixpkgs";

    # neovim-nightly-overlay = {
    #   url = "github:nix-community/neovim-nightly-overlay";
    #   inputs.nixpkgs.follows = "nixpkgs";
    # };

    alejandra = {
      url = "github:kamadorueda/alejandra";
      inputs = {
        fenix.follows = "fenix";
        nixpkgs.follows = "nixpkgs";
      };
    };

    dream2nix = {
      url = "github:nix-community/dream2nix";
      inputs = {
        alejandra.follows = "alejandra";
        devshell.follows = "devshell";
        nixpkgs.follows = "nixpkgs";
      };
    };

    persway = {
      url = "github:johnae/persway/master-stack";
      inputs = {
        devshell.follows = "devshell";
        dream2nix.follows = "dream2nix";
        fenix.follows = "fenix";
        flake-utils.follows = "flake-utils";
        nixpkgs.follows = "nixpkgs";
      };
    };

    ## non flakes
    age-plugin-yubikey = {
      url = "github:str4d/age-plugin-yubikey";
      flake = false;
    };
    blur = {
      url = "github:johnae/blur";
      flake = false;
    };
    rofi-wayland = {
      url = "github:lbonn/rofi/wayland";
      flake = false;
    };
    fish-kubectl-completions = {
      url = "github:evanlucas/fish-kubectl-completions";
      flake = false;
    };
    google-cloud-sdk-fish-completion = {
      url = "github:Doctusoft/google-cloud-sdk-fish-completion";
      flake = false;
    };
    hwdata = {
      url = "github:vcrhonek/hwdata";
      flake = false;
    };
    nixpkgs-fmt = {
      url = "github:nix-community/nixpkgs-fmt";
      flake = false;
    };
    netns-exec = {
      url = "github:johnae/netns-exec";
      flake = false;
    };
    sway = {
      url = "github:swaywm/sway";
      flake = false;
    };
    swayidle = {
      url = "github:swaywm/swayidle";
      flake = false;
    };
    swaylock = {
      url = "github:swaywm/swaylock";
      flake = false;
    };
    wayland-protocols-master = {
      url = "git+https://gitlab.freedesktop.org/wayland/wayland-protocols?ref=main";
      flake = false;
    };
    wlroots = {
      url = "git+https://gitlab.freedesktop.org/wlroots/wlroots?ref=master";
      flake = false;
    };
    wf-recorder = {
      url = "github:ammen99/wf-recorder";
      flake = false;
    };
    wl-clipboard = {
      url = "github:bugaevc/wl-clipboard";
      flake = false;
    };
    kured = {
      url = "github:weaveworks/kured";
      flake = false;
    };
    argocd-install = {
      url = "https://raw.githubusercontent.com/argoproj/argo-cd/v2.5.4/manifests/install.yaml";
      flake = false;
    };
  };

  outputs = {
    self,
    nixpkgs,
    flake-utils,
    ...
  } @ inputs: let
    l = nixpkgs.lib // builtins;

    inherit
      (l)
      attrByPath
      elem
      filter
      filterAttrs
      filterAttrsRecursive
      fromTOML
      hasAttr
      hasPrefix
      isDerivation
      makeOverridable
      mapAttrs
      mapAttrs'
      mapAttrsToList
      mkForce
      mkIf
      mkOverride
      nameValuePair
      nixosSystem
      pathExists
      readDir
      readFile
      recursiveUpdate
      replaceStrings
      substring
      ;

    packageOverlays = import ./packages/overlays.nix {
      inherit inputs;
      inherit (nixpkgs) lib;
    };

    cakeOverlays = {
      pixieboot = final: prev: {inherit (prev.callPackage ./utils/cake.nix {}) pixieboot;};
      lint = final: prev: {inherit (prev.callPackage ./utils/cake.nix {}) lint;};
    };

    overlays =
      [
        inputs.nix-misc.overlay
        inputs.devshell.overlay
        inputs.nur.overlay
        inputs.persway.overlays.default
        inputs.agenix.overlay
        # inputs.neovim-nightly-overlay.overlay
        inputs.fenix.overlay
        (import ./kubernetes/overlay.nix {inherit inputs;})
        (
          final: prev: let
            default_flake = "github:blazed/cake";
            flags = "--use-remote-sudo -L";
          in {
            nixos-upgrade = prev.writeStrictShellScriptBin "nixos-upgrade" ''
              echo Clearing fetcher cache
              echo rm -rf ~/.cache/nix/fetcher-cache-v1.sqlite*
              rm -rf ~/.cache/nix/fetcher-cache-v1.sqlite*
              flake=''${1:-${default_flake}}
              echo nixos-rebuild boot --flake "$flake" ${flags}
              nixos-rebuild boot --flake "$flake" ${flags}
              booted="$(readlink /run/booted-system/{initrd,kernel,kernel-modules})"
              built="$(readlink /nix/var/nix/profiles/system/{initrd,kernel,kernel-modules})"
              if [ "$booted" = "$built" ]; then
                echo nixos-rebuild switch --flake "$flake" ${flags}
                nixos-rebuild switch --flake "$flake" ${flags}
              else
                cat<<MSG
                The system must be rebooted for the changes to take effect
                this is because either all of or some of the kernel, the kernel
                modules or initrd were updated
              MSG
              fi
            '';
          }
        )
      ]
      ++ mapAttrsToList (_: value: value) (packageOverlays // cakeOverlays);

    pkgsFor = system:
      import nixpkgs {
        inherit system overlays;
      };

    forAllNixosSystems = fn:
      flake-utils.lib.eachSystem ["x86_64-linux"]
      (system: fn system (pkgsFor system));

    forAllDefaultSystems = fn:
      flake-utils.lib.eachSystem ["x86_64-linux"]
      (system: fn system (pkgsFor system));

    hostConfigurations = mapAttrs' (
      filename: _: let
        name = replaceStrings [".toml"] [""] filename;
      in {
        inherit name;
        value = fromTOML (readFile (./hosts + "/${filename}"));
      }
    ) (readDir ./hosts);

    nixosConfig = hostName: config: let
      fileOrDir = path: let
        basePath = toString (./. + "/${path}");
      in
        if pathExists basePath
        then basePath
        else "${basePath}.nix";

      hostConf = config.config;
      profiles = map fileOrDir hostConf.profiles;

      userProfiles = mapAttrs (
        _: user: let
          profiles = attrByPath ["profiles"] {} user;
        in
          map fileOrDir profiles
      ) (attrByPath ["home-manager" "users"] {} hostConf);

      modules = [./modules];

      inherit (config) system;

      cfg =
        filterAttrsRecursive (
          name: _:
            name != "profiles"
        )
        hostConf;
    in
      makeOverridable nixosSystem {
        inherit system;
        specialArgs = {
          inherit hostName inputs userProfiles;
          hostConfiguration = cfg;
          hostConfigurations = mapAttrs (_: conf: conf.config) hostConfigurations;
        };
        modules = [
          {
            system.configurationRevision = mkIf (self ? rev) self.rev;
            system.nixos.versionSuffix = mkForce "git.${substring 0 11 nixpkgs.rev}";
            nixpkgs.overlays = overlays;
          }
          (
            {pkgs, ...}: {
              environment.systemPackages = [pkgs.nixos-upgrade];
            }
          )
          inputs.nixpkgs.nixosModules.notDetected
          inputs.home-manager.nixosModules.home-manager
          inputs.agenix.nixosModules.age
          {
            imports = modules ++ profiles;
          }
        ];
      };

    nixosConfigurations = mapAttrs nixosConfig hostConfigurations;

    exportedPackages = forAllDefaultSystems (
      system: pkgs: let
        pkgFilter = name: _:
          hasAttr name pkgs
          && isDerivation pkgs.${name}
          && elem system (attrByPath ["meta" "platforms"] [system] pkgs.${name});
      in {
        packages =
          mapAttrs (name: _: pkgs.${name})
          (filterAttrs pkgFilter (packageOverlays
            // (filterAttrs (name: _: hasPrefix "images/" name) pkgs)
            // cakeOverlays
            // {
              persway = true;
              kured-yaml = true;
              argocd-yaml = true;
              hwdata-master = true;
            }));
      }
    );

    nixosPackages = forAllNixosSystems (system: _: let
      bootSystem = makeOverridable nixosSystem {
        inherit system;
        modules = [
          {
            system.configurationRevision = mkIf (self ? rev) self.rev;
            system.nixos.versionSuffix = mkForce "git.${substring 0 11 nixpkgs.rev}";
            nixpkgs.overlays = overlays;
          }
          inputs.nixpkgs.nixosModules.notDetected
          ({
            modulesPath,
            pkgs,
            lib,
            ...
          }: {
            imports = [
              "${modulesPath}/installer/netboot/netboot-minimal.nix"
              ./cachix.nix
            ];
            nix = {
              settings.trusted-users = ["root"];
              extraOptions = ''
                experimental-features = nix-command flakes
                accept-flake-config = true
              '';
            };
            environment.systemPackages = with pkgs; [git curl jq skim];
            boot.supportedFilesystems = lib.mkForce ["btrfs" "vfat"];
            boot.kernelPackages = pkgs.linuxPackages_latest;
            services.getty.autologinUser = mkForce "root";
            hardware.video.hidpi.enable = true;
            # Enable sshd which gets disabled by netboot-minimal.nix
            systemd.services.sshd.wantedBy = mkOverride 0 ["multi-user.target"];
            users.users.root.openssh.authorizedKeys.keys = [
              "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQC7jrwDFcxP329CNp2kUlGH3cvvrY5DHTJdB6ZsjhpnK1yEVpRrG87TOkxrdBOX+s8bVL/8vR3xgvkaKl67zav9JG1xk9HOYKnAHJ7laLX0WJSHsdL9MHblUbVHnn7rXXQvzwmTUacQlF8h8LiTfGAcSNmj9hrehOzkU1v+mpeOsga7yAMuJWI1Tb7AJ+gzHO/72dEeA5VG0JC43KGMW4yYd12pG/58d9RkaT0Et/rXK7zpYhzaPSl1JlCxYYl12OcjQCoWTz5Bq5jS2cW5dup6/N6kuGdanTGxI4yUIWlUyLPjHUZ5g7EcyBuAE2/v33QUFiwhQjNvHdvhoaoil/T1hye2YJfZ6i+ghrN+jW4Prw2znZ+txRhFlIIXmeEMCBN4aLx5oTWH6qXHRGYjCSPhoU+P8jcagBKTApC0gzNK8jH4nJ8VhGs+g+N2337u5pjjCy9IAN9E8wiODgAvsButF+dFkHXEEzJ9pOrin4/MFUpVQklFwVTTCYP2mXa66zkI+JqoTNCkY5uJPxraxKdq0+0aWjh3KApr5vGA6ZFbkHX3tZdOAWTFZkM46Z3ZxohzWJfJg+eLyAmBbRjJjYU6X5lvb697aksAaqjV2NlkEBxmQTFf9QgrrzfTQubP1Nxj1wnrJd/ytofMIiVMVZ5JLAVIatetV9ZICmxF4j6Tiw=="
              "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDDd9ZjCyGAjtjM6lCVZ46+c3PZvYDzFxECpa3NRwZG8zGnPcbIsFIyQzOdk0eywHFZikNeTxxxiDYXeTnuHuMkweVw5mYIwb8hXj8ts7qoCOVJP9P+KnnEb4WS/edG+Arv1nVeNIXswjHKjOtUSRtoNlRuY0x4kyF9EAbVTrHrB5HDtr7GTGQAGAEp33jQqHrIqFoWmNm9GQ3jqP0b4AcZVRXjAj+amqUQ2+gRt4r1r1kzLuvmOrTbOxnNB/N2hGNCkTbIqP1tDVq03EY0ISOWG+1+TW79ASkSYIdnmQBoB+x6Eh+9CGe65wjM0Op3Q564ZS3Qde1GzMchx5A4W7rrMAOzLXJaQ8Mi7gjsDjrqxBfDDXUU5JL5xn0PhhI1teXvQ5aR90cSs424PS3Yrbqs/pHsybcB/kh25MlO9rGXA9MHh7LlVCPIvus/SDopVgTgNIvhYbQh9xdogkG1XdkvyzXmvAJ6Gk/TR/KRWURwQyp1WJxJ8nHr/zUWrU55zXrN/5gWbDB5k9zuR5G4EGrZshM3EuNeQtjMlHcLWfoZuwaOmar/NOmaXzrBCZb/jXNhQkh6M94krXWE0DIkwsu+5n14llMo/OCxneIEqx4FqZePC8x8qpqfKRzSetOG5PVdCO/8w1erhkg8uETguiPTK4uCfCgtZ75ISpv+7nEwuQ=="
              "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIA0LuxetOJ9SPC0v/icZQxL1+8c58y8I4pp0eb0U8ecQ"
              "sk-ssh-ed25519@openssh.com AAAAGnNrLXNzaC1lZDI1NTE5QG9wZW5zc2guY29tAAAAICCghZ9Q+hC3hwCS8R6KdqQ8RefZgadLQUYC7upCejNCAAAABHNzaDo="
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
                ./result/bin/diskformat 2>&1 | tee -a diskformat.log
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
    in {
      packages.pxebooter = bootSystem.pkgs.symlinkJoin {
        name = "netboot";
        paths = with bootSystem.config.system.build; [
          netbootRamdisk
          kernel
          netbootIpxeScript
        ];
        preferLocalBuild = true;
      };
    });

    diskFormatters = forAllNixosSystems (
      _: pkgs: {packages = mapAttrs' (hostName: config: diskFormatter hostName config pkgs) nixosConfigurations;}
    );

    diskFormatter = hostName: config: pkgs:
      nameValuePair "${hostName}-diskformat" (
        pkgs.callPackage ./utils/diskformat.nix {
          inherit hostName config;
        }
      );
  in
    (forAllDefaultSystems (
      _: pkgs: {
        apps =
          mapAttrs (
            name: drv: {
              type = "app";
              program = "${drv}/bin/${name}";
            }
          ) {
            inherit (pkgs) pixieboot;
            inherit (pkgs) lint;
            inherit (pkgs) nixos-upgrade;
            update-cargo-vendor-sha = pkgs.cake-updaters;
            update-all-cargo-vendor-shas = pkgs.cake-updaters;
            update-fixed-output-derivation-sha = pkgs.cake-updaters;
            update-all-fixed-output-derivation-shas = pkgs.cake-updaters;
          };
        devShells.default = pkgs.devshell.mkShell {
          imports = [
            (pkgs.devshell.importTOML ./devshell.toml)
          ];
        };
      }
    ))
    // (
      forAllDefaultSystems (
        _: pkgs: {
          formatter = pkgs.alejandra;
        }
      )
    )
    // {
      inherit nixosConfigurations hostConfigurations;

      packages = recursiveUpdate (recursiveUpdate nixosPackages.packages exportedPackages.packages) diskFormatters.packages;

      overlays =
        packageOverlays
        // cakeOverlays
        // {
          persway = inputs.persway.overlays.default;
        };

      github-actions-package-matrix-x86-64-linux = let
        pkgs = pkgsFor "x86_64-linux";
        skip = mapAttrsToList (name: _: name) (filterAttrs (name: _: hasPrefix "images/" name) pkgs);
      in {
        os = ["ubuntu-latest"];
        pkg = filter (item: !(elem item skip)) (mapAttrsToList (name: _: name) exportedPackages.packages.x86_64-linux);
      };

      github-actions-host-matrix-x86-64-linux = {
        os = ["ubuntu-latest"];
        host = mapAttrsToList (name: _: name) (filterAttrs (_: config: config.system == "x86_64-linux") hostConfigurations);
      };
    };
}
