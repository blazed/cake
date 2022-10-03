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
      "/var/lib/containers"
      "/var/lib/docker"
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
            "/home/${userName}/code"
          ];

          files = [
            "/home/${userName}/.ssh/known_hosts"
          ];
        }
    ) (filterAttrs (_: user: user.isNormalUser) users);
  };
}
