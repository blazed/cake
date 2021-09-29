{ pkgs, lib, config, ... }:
let
  inherit (lib) mkForce;
in
{
  services.deluge = {
    enable = true;
    declarative = true;
    authFile = "/var/lib/deluge/auth";
    openFirewall = true;
    web.enable = true;
    config = {
      download_location = "/mnt/media/torrents/incomplete";
      dht = false;
      upnp = false;
      utpex = false;
      lsd = false;
      natpmp = false;
      copy_torrent_file = true;
      torrentfiles_location = "/mnt/media/torrents/saved_torrents";
      move_completed = true;
      move_completed_path = "/mnt/media/torrents/finished";
      random_port = false;
      listen_ports = [ 57788 57788 ];
      enabled_plugins = [ "Label" "Stats" "SimpleExtractor" ];
      max_active_seeding = -1;
      max_active_downloading = 5;
      max_active_limit = -1;
      stop_seed_at_ratio = false;
      remove_seed_at_ratio = false;
      stop_seed_ratio = 2.0;
      share_ratio_limit = 2.0;
      seed_time_limit = 10080;
      seed_time_ratio_limit = -1;
      max_upload_slots_global = -1;
      dont_count_slow_torrents = true;
      max_connections_global = 1000;
      auto_managed = false;
    };
  };

  systemd.services.deluged = {
    bindsTo = [ "wireguard-private.service" ];
    after = [ "wireguard-private.service" "mnt-media.mount" ];
    serviceConfig = {
      ExecStart = mkForce "/run/wrappers/bin/netns-exec private ${pkgs.deluge}/bin/deluged --do-not-daemonize --config ${config.services.deluge.dataDir}/.config/deluge";
    };
  };

  systemd.services.deluged-forwarder = {
    enable = true;
    after = [ "deluged.service" ];
    bindsTo = [ "deluged.service" ];
    wantedBy = [ "multi-user.target" ];
    script = ''
      ${pkgs.socat}/bin/socat tcp-listen:55846,fork,reuseaddr,bind=127.0.0.1 exec:'/run/wrappers/bin/netns-exec private ${pkgs.socat}/bin/socat STDIO "tcp-connect:127.0.0.1:55846"',nofork
    '';
  };

  services.plex = {
    enable = true;
    openFirewall = true;
    user = "deluge";
    group = "deluge";
  };

  systemd.services.plex = {
    after = [ "mnt-media.mount" ];
  };

  services.sonarr = {
    enable = true;
    openFirewall = true;
    user = "deluge";
    group = "deluge";
  };

  services.radarr = {
    enable = true;
    openFirewall = true;
    user = "deluge";
    group = "deluge";
  };

  services.jackett = {
    enable = true;
    openFirewall = true;
    user = "deluge";
    group = "deluge";
  };

  environment.state."/keep".directories = [
    "/var/lib/plex"
    "/var/lib/deluge"
    "/var/lib/radarr"
    "/var/lib/sonarr"
    "/var/lib/jackett"
  ];
}
