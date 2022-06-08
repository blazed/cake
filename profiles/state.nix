{
  config,
  lib,
  ...
}: let
  inherit (lib) mapAttrs' nameValuePair filterAttrs;
  inherit (builtins) toString;
  users = config.users.users;
in {
  environment.state."/keep" = {
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

    users = mapAttrs' (
      userName: conf:
        nameValuePair (toString conf.uid) {
          directories = [
            "/home/${userName}/code"
          ];

          files = [
            "/home/${userName}/.ssh/known_hosts"
            "/home/${userName}/.config/gopass/config.yml"
          ];
        }
    ) (filterAttrs (_: user: user.isNormalUser) users);
  };
}
