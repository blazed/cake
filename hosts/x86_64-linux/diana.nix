{
  adminUser,
  hostName,
  ...
}: {
  publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINS32enSwJ3QsudwfrRcerKR/2zLZwERJhimbgBcye67";

  imports = [
    ../../profiles/admin-user/home-manager.nix
    ../../profiles/admin-user/user.nix
    ../../profiles/disk/btrfs-on-luks.nix
    ../../profiles/greetd.nix
    ../../profiles/hardware/xps9300.nix
    ../../profiles/home-manager.nix
    ../../profiles/laptop.nix
    ../../profiles/restic-backup.nix
    ../../profiles/state.nix
    ../../profiles/tailscale.nix
    ../../profiles/zram.nix
  ];

  boot.initrd = {
    systemd.enable = true;
  };

  age.secrets = {
    codeium-token = {
      file = ../../secrets/codeium-token.age;
      owner = "${toString adminUser.uid}";
      path = "/home/${adminUser.name}/.local/share/.codeium/config.json";
    };
    wifi-networks = {
      file = ../../secrets/wifi-networks.age;
    };
    wg-private = {
      file = ../../secrets/${hostName}/wg-private.age;
    };
  };

  networking.private-wireguard.enable = true;
  networking.private-wireguard.ips = [
    "10.68.41.158/32"
    "fc00:bbbb:bbbb:bb01::5:299d/128"
  ];
  networking.private-wireguard.privateKeyFile = "/run/agenix/wg-private";
  networking.private-wireguard.peers = [
    {
      publicKey = "94qIvXgF0OXZ4IcquoS7AO57OV6JswUFgdONgGiq+jo=";
      allowedIPs = [ "0.0.0.0/0" "::0/0" ];
      endpoint = "185.65.135.69:51820";
      persistentKeepalive = 25;
    }
  ];

  home-manager = {
    users.${adminUser.name} = {
      imports = [../../users/profiles/workstation.nix];
      programs.git.extraConfig.user.signingKey = "key::sk-ssh-ed25519@openssh.com AAAAGnNrLXNzaC1lZDI1NTE5QG9wZW5zc2guY29tAAAAICCghZ9Q+hC3hwCS8R6KdqQ8RefZgadLQUYC7upCejNCAAAABHNzaDo=";
    };
  };
}
