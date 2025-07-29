{
  adminUser,
  config,
  ...
}:
{
  publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOkSM4q2znIpCSJA60RtjKYWaz+hBhjjzJfP7SDL32is";

  imports = [
    ../../profiles/hardware/usbcore.nix
    ../../profiles/hardware/x570.nix
    ../../profiles/admin-user/home-manager.nix
    ../../profiles/admin-user/user.nix
    ../../profiles/disk/btrfs-on-luks.nix
    ../../profiles/desktop.nix
    ../../profiles/greetd.nix
    ../../profiles/home-manager.nix
    ../../profiles/restic-backup.nix
    ../../profiles/state.nix
    ../../profiles/tailscale.nix
    ../../profiles/zram.nix

    ../../profiles/github-runner.nix
  ];

  boot.loader.systemd-boot.memtest86.enable = true;

  boot.initrd = {
    systemd.enable = true;
  };

  services.ratbagd.enable = true;

  age.secrets = {
    id_ed25519 = {
      file = ../../secrets/id_ed25519.age;
      owner = "${toString adminUser.uid}";
      path = "/home/${adminUser.name}/.ssh/id_ed25519";
    };
    copilot-apps-json = {
      file = ../../secrets/copilot-apps-json.age;
      owner = "${toString adminUser.uid}";
      path = "/home/${adminUser.name}/.config/github-copilot/apps.json";
    };
    anthropic-api-key = {
      file = ../../secrets/anthropic-api-key.age;
      owner = "${toString adminUser.uid}";
    };
    copilot-api-key = {
      file = ../../secrets/copilot-api-key.age;
      owner = "${toString adminUser.uid}";
    };
    github-runner = {
      file = ../../secrets/github-runner-token-exsules.age;
      owner = "${toString adminUser.uid}";
    };
  };

  programs.steam.enable = true;
  services.flatpak.enable = true;

  services.input-remapper.enable = true;

  services.ollama.acceleration = "rocm";
  services.ollama.rocmOverrideGfx = "10.3.0";

  environment.persistence."/keep" = {
    users.${adminUser.name} = {
      directories = [
        ".config/input-remapper-2"
      ];
    };
  };

  home-manager = {
    users.${adminUser.name} = {
      imports = [ ../../users/profiles/workstation.nix ];
      programs.git.extraConfig.user.signingKey =
        "key::sk-ssh-ed25519@openssh.com AAAAGnNrLXNzaC1lZDI1NTE5QG9wZW5zc2guY29tAAAAIH8FItRsdPvpg8mTCF7gsKQJ4ABaOCE8a6PzamumRWe3AAAABHNzaDo=";
      programs.jujutsu.settings.signing = {
        behavior = "own";
        backend = "ssh";
        key = config.age.secrets.id_ed25519.path;
      };
    };
  };

  networking.wireguard.enable = true;
}
