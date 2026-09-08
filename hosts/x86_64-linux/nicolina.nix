{
  adminUser,
  config,
  inputs,
  lib,
  pkgs,
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
    ../../profiles/workstation.nix
    inputs.arctis-sound-manager.nixosModules.default
    ../../profiles/greeter.nix
    ../../profiles/home-manager.nix
    ../../profiles/restic-backup.nix
    ../../profiles/state.nix
    ../../profiles/tailscale.nix
    ../../profiles/zram.nix

    ../../profiles/k3s-agent.nix
  ];

  boot.loader.systemd-boot.memtest86.enable = true;

  boot.initrd = {
    systemd.enable = true;
  };

  services.ratbagd.enable = true;

  services.arctis-sound-manager.enable = true;

  age.secrets = {
    k3s-token = {
      file = ../../secrets/k3s/token.age;
    };
    k3s-node-lifecycle = {
      file = ../../secrets/k3s/node-lifecycle-kubeconfig.age;
    };
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
    exa-api-key = {
      file = ../../secrets/exa-api-key.age;
      owner = "${toString adminUser.uid}";
    };
    proton-pass-agent-token = {
      file = ../../secrets/proton-pass-agent-token.age;
      owner = "${toString adminUser.uid}";
    };
  };

  networking.firewall = {
    trustedInterfaces = [
      "lo"
      "cilium_host"
      "cilium_net"
      "cilium_vxlan"
      "lxc+"
      "eth+"
      "wlan+"
      "enp+"
      "enp4s0"
    ];
  };

  programs.steam.enable = true;

  services.input-remapper.enable = true;

  environment.persistence."/keep" = {
    users.${adminUser.name} = {
      directories = [
        ".config/arctis_manager"
        ".config/input-remapper-2"
        ".local/share/pipewire/hrir_hesuvi"
      ];
    };
  };

  home-manager = {
    users.${adminUser.name} = { lib, ... }: {
      imports = [ ../../users/profiles/workstation.nix ];
      home.activation.arctisRouting = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        run ${
          (pkgs.python3.withPackages (ps: [ ps.ruamel-yaml ]))
        }/bin/python ${pkgs.writeText "arctis-routing.py" ''
          import json
          import os
          from pathlib import Path
          from ruamel.yaml import YAML

          root = Path(os.environ.get("XDG_CONFIG_HOME") or Path.home() / ".config") / "arctis_manager"
          yaml = YAML()

          # Keep these files writable for ASM; preserve unrelated GUI settings.
          def merge(relative, updates, load, dump):
              path = root / relative
              data = load(path.read_text()) if path.exists() else {}
              if not isinstance(data, dict):
                  raise ValueError(f"Expected a mapping in {path}; refusing to overwrite it")
              data.update(updates)
              path.parent.mkdir(parents=True, exist_ok=True)
              temporary = path.with_name(path.name + ".cake-tmp")
              try:
                  with temporary.open("w") as stream:
                      dump(data, stream)
                  temporary.replace(path)
              finally:
                  temporary.unlink(missing_ok=True)

          merge("routing_overrides.json", {
              "Firefox": "Arctis_Media",
              "spotify": "Arctis_Media",
          }, json.loads, lambda data, stream: json.dump(data, stream, indent=2))
          # ASM selects Media on connect and a non-Arctis sink on disconnect.
          # Its router already recognizes browsers, common chat apps and Wine/Proton.
          merge("settings/general_settings.yaml", {
              "redirect_audio_on_connect": True,
              "redirect_audio_on_disconnect": True,
          }, yaml.load, yaml.dump)
        ''}
      '';
      wayland.windowManager.sway.config.startup = [
        { command = "asm-gui --systray"; }
      ];
      programs.git.settings = {
        # user.signingKey = "key::sk-ssh-ed25519@openssh.com AAAAGnNrLXNzaC1lZDI1NTE5QG9wZW5zc2guY29tAAAAIH8FItRsdPvpg8mTCF7gsKQJ4ABaOCE8a6PzamumRWe3AAAABHNzaDo=";
        user.signingKey = config.age.secrets.id_ed25519.path;
      };
      programs.jujutsu.settings.signing = {
        behavior = "own";
        backend = "ssh";
        key = config.age.secrets.id_ed25519.path;
      };
    };
  };

  services.k3s.serverAddr = "https://10.0.10.10:6443";
  services.k3s.settings.node-label."exsules.com/lan-l2" = "true";

  services.tailscale.auth.enable = lib.mkForce false;

  networking.wireguard.enable = true;

  programs.virt-manager.enable = true;
  users.groups.libvirtd.members = [ adminUser.name ];
  users.users.${adminUser.name}.extraGroups = [ "libvirtd" ];
  virtualisation.libvirtd.enable = true;
  virtualisation.spiceUSBRedirection.enable = true;

}
