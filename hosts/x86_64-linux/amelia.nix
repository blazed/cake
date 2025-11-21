{
  adminUser,
  config,
  ...
}:
{
  publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHFFeGviKto0uzeSJBZglLrAQmpwGqIQie61A6MqmiOT";

  imports = [
    ../../profiles/admin-user/home-manager.nix
    ../../profiles/admin-user/user.nix
    ../../profiles/disk/btrfs-on-luks.nix
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

  boot.loader.systemd-boot.memtest86.enable = true;

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
  };

  home-manager = {
    users.${adminUser.name} = {
      imports = [ ../../users/profiles/workstation.nix ];
      programs.git.settings.user.signingKey = config.age.secrets.id_ed25519.path;
      programs.jujutsu.settings.signing = {
        behavior = "own";
        backend = "ssh";
        key = config.age.secrets.id_ed25519.path;
      };
    };
  };
}
