{ config, lib, ... }:
let
  inherit (lib) mapAttrs' nameValuePair filterAttrs;
  inherit (builtins) toString;
  users = config.users.users;
in
{
  environment.state."/keep" = 
    {
      directories = [
        "/var/log"
        "/var/lib/containers"
        "/var/lib/wireguard"
        "/var/lib/tailscale"
        "/var/lib/libvirt"
        "/var/lib/docker"
        "/root"
      ];

      files = [
        "/etc/machine-id"
        "/etc/ssh/ssh_host_rsa_key"
        "/etc/ssh/ssh_host_ed25519_key"
        "/etc/ssh/ssh_host_rsa_key.pub"
        "/etc/ssh/ssh_host_ed25519_key.pub"
      ];

      users = mapAttrs' (userName: conf:
        nameValuePair (toString conf.uid) {
          directories = [
            # "/home/${userName}/Downloads"
            # "/home/${userName}/Documents"
            # "/home/${userName}/Games"
            # "/home/${userName}/Pictures"
            "/home/${userName}/code"
            # "/home/${userName}/vms"
            # "/home/${userName}/.local/share/direnv"
            # "/home/${userName}/.local/share/fish"
            # "/home/${userName}/.local/share/containers"
            # "/home/${userName}/.local/share/lutris"
            # "/home/${userName}/.local/share/Steam"
            # "/home/${userName}/.local/share/vulkan"
            # "/home/${userName}/.local/share/TelegramDesktop"
            # "/home/${userName}/.mail"
            # "/home/${userName}/.steam"
            # "/home/${userName}/.cache/mu"
            # "/home/${userName}/.cache/nix"
            # "/home/${userName}/.cache/nix-index"
            # "/home/${userName}/.cache/vim"
            # "/home/${userName}/.mozilla/firefox"
            # "/home/${userName}/.gnupg"
            # "/home/${userName}/.config/gcloud"
            # "/home/${userName}/.config/discord"
            # "/home/${userName}/.config/lutris"
            # "/home/${userName}/.config/pipewire"
            # "/home/${userName}/.config/Signal"
            # "/home/${userName}/.config/spotify"
            # "/home/${userName}/.config/obs-studio"
            # "/home/${userName}/.config/WowUp"
            # "/home/${userName}/.config/warcraftlogs"
            # "/home/${userName}/.backup/undo"
            # "/home/${userName}/.factorio"
            # "/home/${userName}/.wine"
            # "/home/${userName}/.terraform.d"
          ];

          files = [
            # "/home/${userName}/.kube/config"
            "/home/${userName}/.ssh/known_hosts"
            "/home/${userName}/.config/gopass/config.yml"
          ];
        }
      ) (filterAttrs (_: user: user.isNormalUser) users);
    };
}
