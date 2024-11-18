{
  adminUser,
  ...
}: {
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
    ../../profiles/ollama.nix
    ../../profiles/restic-backup.nix
    ../../profiles/state.nix
    ../../profiles/tailscale.nix
    ../../profiles/zram.nix
  ];

  boot.loader.systemd-boot.memtest86.enable = true;

  boot.initrd = {
    systemd.enable = true;
  };

  services.ratbagd.enable = true;

  age.secrets = {
    codeium-token = {
      file = ../../secrets/codeium-token.age;
      owner = "${toString adminUser.uid}";
      path = "/home/${adminUser.name}/.local/share/.codeium/config.json";
    };
  };

  programs.steam.enable = true;
  services.flatpak.enable = true;

  services.input-remapper.enable = true;

  services.ollama.acceleration = "rocm";

  environment.persistence."/keep" = {
    users.${adminUser.name} = {
      directories = [
        ".config/input-remapper-2"
      ];
    };
  };

  home-manager = {
    users.${adminUser.name} = {
      imports = [../../users/profiles/workstation.nix];
      programs.git.extraConfig.user.signingKey = "key::sk-ssh-ed25519@openssh.com AAAAGnNrLXNzaC1lZDI1NTE5QG9wZW5zc2guY29tAAAAIH8FItRsdPvpg8mTCF7gsKQJ4ABaOCE8a6PzamumRWe3AAAABHNzaDo=";
    };
  };
}
