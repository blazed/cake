{
  adminUser,
  config,
  ...
}: {
  publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIP/WquqAPOAkYE10UcU+P1b2IagzlZ1uQyG2g4WnO5/X";

  imports = [
    ../../profiles/admin-user/home-manager.nix
    ../../profiles/admin-user/user.nix
    ../../profiles/disk/bcachefs-on-luks.nix
    ../../profiles/greetd.nix
    ../../profiles/hardware/usbcore.nix
    ../../profiles/hardware/framework-13-amd.nix
    ../../profiles/home-manager.nix
    ../../profiles/laptop.nix
    ../../profiles/restic-backup.nix
    ../../profiles/state.nix
    ../../profiles/tailscale.nix
    ../../profiles/zram.nix
  ];

  bcachefs = {
    disks = ["/dev/nvme0n1"];
    devices = ["/dev/mapper/encrypted_root"];
  };

  boot.initrd = {
    systemd.enable = true;
  };

  age.secrets = {
    id_ed25519 = {
      file = ../../secrets/id_ed25519.age;
      owner = "${toString adminUser.uid}";
      path = "/home/${adminUser.name}/.ssh/id_ed25519";
    };
    wifi-networks = {
      file = ../../secrets/wifi-networks.age;
    };
  };

  home-manager = {
    users.${adminUser.name} = {
      imports = [../../users/profiles/workstation.nix];
      programs.git.extraConfig.user.signingKey = config.age.secrets.id_ed25519.path;
      programs.jujutsu.settings.signing = {
        sign-all = true;
        backend = "ssh";
        key = config.age.secrets.id_ed25519.path;
      };
    };
  };
}
