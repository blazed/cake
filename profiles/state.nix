{
  config,
  lib,
  ...
}: let
  inherit (lib) mapAttrs' nameValuePair filterAttrs;
  inherit (builtins) toString;
  inherit (config.users) users;
in {
  environment.state."/keep" = {
    directories = [
      "/root"
      "/var/lib/bluetooth"
      "/var/lib/containers"
      "/var/lib/docker"
      "/var/lib/systemd"
      "/var/lib/flatpak"
      "/var/lib/libvirt"
      "/var/lib/tailscale"
      "/var/lib/wireguard"
      "/var/log"
    ];

    files = [
      "/etc/machine-id"
      "/etc/ssh/ssh_host_ed25519_key"
      "/etc/ssh/ssh_host_ed25519_key.pub"
      "/etc/ssh/ssh_host_rsa_key"
      "/etc/ssh/ssh_host_rsa_key.pub"
    ];

    users = mapAttrs' (
      userName: conf:
        nameValuePair (toString conf.uid) {
          directories = [
            "/home/${userName}/.backup/undo"
            "/home/${userName}/.cache/mu"
            "/home/${userName}/.cache/nix"
            "/home/${userName}/.cache/nix-index"
            "/home/${userName}/.cache/rbw"
            "/home/${userName}/.cache/vim"
            "/home/${userName}/.cache/monero-project"
            "/home/${userName}/.cargo"
            "/home/${userName}/.config/Insomnia"
            "/home/${userName}/.config/Signal"
            "/home/${userName}/.config/WowUpCf"
            "/home/${userName}/.config/discord"
            "/home/${userName}/.config/easyeffects"
            "/home/${userName}/.config/gcloud"
            "/home/${userName}/.config/gh"
            "/home/${userName}/.config/github-copilot"
            "/home/${userName}/.config/lutris"
            "/home/${userName}/.config/monero-project"
            "/home/${userName}/.config/obs-studio"
            "/home/${userName}/.config/pipewire"
            "/home/${userName}/.config/pulse"
            "/home/${userName}/.config/spotify"
            "/home/${userName}/.config/warcraftlogs"
            "/home/${userName}/.factorio"
            "/home/${userName}/.gnupg"
            "/home/${userName}/.local/share/Steam"
            "/home/${userName}/.local/share/TelegramDesktop"
            "/home/${userName}/.local/share/containers"
            "/home/${userName}/.local/share/direnv"
            "/home/${userName}/.local/share/fish"
            "/home/${userName}/.local/share/flatpak"
            "/home/${userName}/.local/share/lutris"
            "/home/${userName}/.local/share/nix"
            "/home/${userName}/.local/share/vulkan"
            "/home/${userName}/.local/state/pipewire/media-session.d"
            "/home/${userName}/.local/state/wireplumber"
            "/home/${userName}/.mail"
            "/home/${userName}/.mozilla"
            "/home/${userName}/.steam"
            "/home/${userName}/.terraform.d"
            "/home/${userName}/.var"
            "/home/${userName}/.wine"
            "/home/${userName}/Documents"
            "/home/${userName}/Downloads"
            "/home/${userName}/Games"
            "/home/${userName}/Photos"
            "/home/${userName}/Pictures"
            "/home/${userName}/code"
          ];

          files = [
            "/home/${userName}/.kube/config"
            "/home/${userName}/.ssh/known_hosts"
          ];
        }
    ) (filterAttrs (_: user: user.isNormalUser) users);
  };
}
