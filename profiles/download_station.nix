{
  pkgs,
  lib,
  ...
}:
let
  mediaUser = "media";
  mediaGroup = "media";
  webuiPort = 8080;
  netnsPath = "/var/run/netns/private";
in
{
  users.groups.${mediaGroup} = { };
  users.users.${mediaUser} = {
    isSystemUser = true;
    group = mediaGroup;
  };

  services.qbittorrent = {
    enable = true;
    openFirewall = false;
    user = mediaUser;
    group = mediaGroup;
    inherit webuiPort;
    torrentingPort = null;
    serverConfig = {
      LegalNotice.Accepted = true;
      Preferences = {
        WebUI.LocalHostAuth = false;
        WebUI.CSRFProtection = false;
        Advanced.AnnounceToAllTrackers = true;
      };
      BitTorrent.Session = {
        DefaultSavePath = "/mnt/media/torrents/finished";
        TempPath = "/mnt/media/torrents/incomplete";
        TempPathEnabled = true;
        # Placeholder; natpmp-forward overwrites listen_port via the Web API once Proton
        # grants a lease. Explicit value avoids a random-port window before first refresh.
        Port = 6881;
        UseRandomPort = false;
        UseNATForwarding = false;
        DHTEnabled = false;
        PeXEnabled = false;
        LSDEnabled = false;
        Encryption = 1;
        AnonymousModeEnabled = false;
        GlobalMaxSeedingMinutes = 12960;
        MaxConnections = 1000;
        MaxUploads = 20;
        MaxActiveUploads = 20;
        MaxActiveTorrents = 500;
        MaxConnectionsPerTorrent = 200;
        MaxUploadsPerTorrent = 10;
        QueueingSystemEnabled = true;
        ShareLimitAction = "Remove";
      };
      RSS.AutoDownloader = {
        DownloadRepacks = false;
        SmartEpisodeFilter = "";
      };
    };
  };

  # Per-netns resolv.conf for services pinned via NetworkNamespacePath.
  # systemd does not bind-mount /etc/netns/<ns>/resolv.conf the way
  # `ip netns exec` does, so sandboxed services inherit the host resolver —
  # which is usually unreachable from inside the VPN netns. Point at the
  # VPN's in-tunnel resolver instead (10.2.0.1 for Proton).
  environment.etc."netns/private/resolv.conf".text = ''
    nameserver 10.2.0.1
  '';

  systemd.services.qbittorrent = {
    bindsTo = [ "wireguard-private.service" ];
    after = [
      "wireguard-private.service"
      "mnt-media.mount"
    ];
    serviceConfig = {
      NetworkNamespacePath = netnsPath;
      BindReadOnlyPaths = [
        netnsPath
        "/etc/netns/private/resolv.conf:/etc/resolv.conf"
      ];
    };
  };

  # Bridge the host's WebUI port to qBittorrent inside the private netns.
  # Outer socat runs in the root netns (listens on all interfaces so LAN clients
  # can reach it); inner socat is re-executed per connection via nsenter into
  # the private netns.
  systemd.services.qbittorrent-forwarder = {
    description = "Forward qBittorrent WebUI from host to private netns";
    after = [ "qbittorrent.service" ];
    bindsTo = [ "qbittorrent.service" ];
    wantedBy = [ "multi-user.target" ];
    script = ''
      ${pkgs.socat}/bin/socat tcp-listen:${toString webuiPort},fork,reuseaddr exec:'${pkgs.util-linux}/bin/nsenter --net=${netnsPath} ${pkgs.socat}/bin/socat STDIO "tcp-connect:127.0.0.1:${toString webuiPort}"',nofork
    '';
  };

  networking.firewall.allowedTCPPorts = [ webuiPort ];

  systemd.services.natpmp-forward = {
    description = "Refresh Proton VPN NAT-PMP port lease and push it to qBittorrent";
    bindsTo = [
      "wireguard-private.service"
      "qbittorrent.service"
    ];
    after = [
      "wireguard-private.service"
      "qbittorrent.service"
    ];
    wantedBy = [ "multi-user.target" ];
    path = [
      pkgs.libnatpmp
      pkgs.curl
      pkgs.gawk
      pkgs.coreutils
    ];
    serviceConfig = {
      Restart = "on-failure";
      RestartSec = "10s";
      NetworkNamespacePath = netnsPath;
      BindReadOnlyPaths = [
        netnsPath
        "/etc/netns/private/resolv.conf:/etc/resolv.conf"
      ];
    };
    script = ''
      set -u
      last_port=""
      while :; do
        if ! out=$(natpmpc -a 1 0 udp 60 -g 10.2.0.1 && natpmpc -a 1 0 tcp 60 -g 10.2.0.1); then
          echo "natpmpc failed; retrying in 5s"
          sleep 5
          continue
        fi
        port=$(echo "$out" | awk '/Mapped public port/ {print $4; exit}')
        if [ -n "$port" ] && [ "$port" != "$last_port" ]; then
          echo "Updating qBittorrent listen_port: ''${last_port:-unset} -> $port"
          if curl -fsS -X POST "http://127.0.0.1:${toString webuiPort}/api/v2/app/setPreferences" \
               --data-urlencode "json={\"listen_port\":$port,\"random_port\":false,\"upnp\":false}"; then
            last_port=$port
          else
            echo "qBittorrent API update failed; will retry"
          fi
        fi
        sleep 45
      done
    '';
  };

  services.jellyfin = {
    enable = true;
    openFirewall = true;
    user = mediaUser;
    group = mediaGroup;
  };

  systemd.services.jellyfin = {
    after = [ "mnt-media.mount" ];
  };

  services.seerr = {
    enable = true;
    openFirewall = true;
  };

  systemd.services.seerr = {
    after = [ "mnt-media.mount" ];
    serviceConfig = {
      DynamicUser = lib.mkForce false;
      User = mediaUser;
      Group = mediaGroup;
    };
  };

  services.sonarr = {
    enable = true;
    openFirewall = true;
    user = mediaUser;
    group = mediaGroup;
  };

  services.radarr = {
    enable = true;
    openFirewall = true;
    user = mediaUser;
    group = mediaGroup;
  };

  services.prowlarr = {
    enable = true;
    openFirewall = true;
  };

  systemd.services.prowlarr.serviceConfig = {
    DynamicUser = lib.mkForce false;
    StateDirectory = lib.mkForce null;
    User = mediaUser;
    Group = mediaGroup;
  };

  services.flaresolverr = {
    enable = true;
    openFirewall = true;
  };

  environment.persistence."/keep".directories = [
    "/var/lib/qBittorrent"
    "/var/lib/jellyfin"
    "/var/lib/jellyseerr"
    "/var/lib/prowlarr"
    "/var/lib/radarr"
    "/var/lib/sonarr"
  ];
}
