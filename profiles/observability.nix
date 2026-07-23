{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.modules.observability;
in
{
  options.modules.observability = {
    enable = lib.mkEnableOption "observability — host metrics + log shipping";

    lokiURL = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "http://loki.tailef5cf.ts.net:3100/loki/api/v1/push";
      description = ''
        Loki push endpoint URL. When non-null, Grafana Alloy is
        enabled and ships systemd-journal entries here. Leave null
        to skip log shipping (metrics still work).
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    # Host metrics. node_exporter binds 0.0.0.0:9100 by default; the
    # router's nftables policy drops unsolicited WAN ingress and only
    # accepts trusted-interface traffic, so it's not publicly reachable.
    services.prometheus.exporters.node = {
      enable = true;
      port = 9100;
      enabledCollectors = [
        "conntrack"
        "systemd"
        "textfile"
        "processes"
      ];
      extraFlags = [
        "--collector.textfile.directory=/var/lib/node_exporter/textfile"
        "--collector.systemd.enable-restarts-metrics"
        "--collector.systemd.enable-start-time-metrics"
        "--collector.systemd.enable-task-metrics"
      ];
    };

    systemd.tmpfiles.rules = [
      "d /var/lib/node_exporter/textfile 0755 nobody nobody -"
    ];

    # dnsmasq metrics — only meaningful where dnsmasq is in use.
    services.prometheus.exporters.dnsmasq = lib.mkIf config.services.dnsmasq.enable {
      enable = true;
      port = 9153;
      dnsmasqListenAddress = "127.0.0.1:53";
      leasesPath = "/var/lib/dnsmasq/dnsmasq.leases";
    };

    # Alloy: read systemd-journal and push to Loki. Only enabled when a
    # push URL is configured — this profile is otherwise metrics-only.
    services.alloy = lib.mkIf (cfg.lokiURL != null) {
      enable = true;
      extraFlags = [ "--disable-reporting" ];
      configPath = pkgs.writeText "config.alloy" ''
        loki.write "default" {
          endpoint {
            url = "${cfg.lokiURL}"
          }
        }

        loki.relabel "journal" {
          forward_to = []
          rule {
            source_labels = ["__journal__systemd_unit"]
            target_label  = "unit"
          }
          rule {
            source_labels = ["__journal_priority_keyword"]
            target_label  = "level"
          }
        }

        loki.source.journal "default" {
          forward_to    = [loki.write.default.receiver]
          relabel_rules = loki.relabel.journal.rules
          max_age       = "12h"
          labels        = {
            job  = "systemd-journal",
            host = "${config.networking.hostName}",
          }
        }
      '';
    };
  };
}
