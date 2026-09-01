{
  config,
  lib,
  pkgs,
  ...
}:
let
  service = "svc:frigate";

  frigate-deep-describe = pkgs.writeShellApplication {
    name = "frigate-deep-describe";
    runtimeInputs = with pkgs; [
      curl
      jq
      coreutils
    ];
    text = ''
      api=http://127.0.0.1:5000
      llm=http://127.0.0.1:9292
      tmp=$(mktemp -d)
      trap 'rm -rf "$tmp"' EXIT

      after=$(date -d '24 hours ago' +%s)
      curl -sSf "$api/api/events?after=$after&has_snapshot=1&limit=200" \
        | jq -r '.[] | [.id, .camera, .label] | @tsv' \
        | while IFS=$'\t' read -r id camera label; do
            curl -sf "$api/api/events/$id/snapshot.jpg" -o "$tmp/snap.jpg" || continue
            base64 -w0 "$tmp/snap.jpg" > "$tmp/b64"
            jq -n --rawfile img "$tmp/b64" --arg camera "$camera" --arg label "$label" '{
              model: "camera-vlm-deep",
              max_tokens: 4096,
              messages: [{
                role: "user",
                content: [
                  { type: "text",
                    text: "This is a snapshot of a security-camera event from camera \($camera), where a \($label) was detected. Describe the \($label), its appearance and its activity in 2-4 sentences, noting anything unusual. Mention only what is visible in the image." },
                  { type: "image_url", image_url: { url: ("data:image/jpeg;base64," + $img) } }
                ]
              }]
            }' > "$tmp/req.json"
            # Generous timeout: the first request may wait on the 27B model load.
            desc=$(curl -sf --max-time 900 "$llm/v1/chat/completions" \
              -H 'content-type: application/json' -d @"$tmp/req.json" \
              | jq -er '.choices[0].message.content') || continue
            [ -n "$desc" ] || continue
            jq -n --arg d "$desc" '{description: $d}' \
              | curl -sf -X POST "$api/api/events/$id/description" \
                  -H 'content-type: application/json' -d @- > /dev/null \
              && echo "described $id ($camera/$label)"
          done
    '';
  };

  cameras = lib.attrNames config.services.frigate.settings.cameras;
  ffmpeg = "${config.services.frigate.settings.ffmpeg.path}/bin/ffmpeg";
  timelapseDir = "/var/lib/timelapse";

  timelapse-grab = pkgs.writeShellApplication {
    name = "timelapse-grab";
    runtimeInputs = [ pkgs.coreutils ];
    text = ''
      day=$(date +%F)
      cams=(${lib.escapeShellArgs cameras})
      for cam in "''${cams[@]}"; do
        dir=${timelapseDir}/frames/$cam/$day
        mkdir -p "$dir"
        ${ffmpeg} -hide_banner -v error -rtsp_transport tcp \
          -i "rtsp://127.0.0.1:8554/$cam" \
          -frames:v 1 -q:v 2 "$dir/$(date +%H%M%S).jpg" || continue
      done
    '';
  };

  timelapse-stitch = pkgs.writeShellApplication {
    name = "timelapse-stitch";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.findutils
    ];
    text = ''
      day=$(date -d yesterday +%F)
      cams=(${lib.escapeShellArgs cameras})
      for cam in "''${cams[@]}"; do
        dir=${timelapseDir}/frames/$cam/$day
        [ -d "$dir" ] || continue
        # Drop frameless days (dead camera) instead of failing on them forever.
        [ -n "$(find "$dir" -name '*.jpg' | head -1)" ] || { rm -rf "$dir"; continue; }
        ${ffmpeg} -hide_banner -v error -framerate 30 -pattern_type glob \
          -i "$dir/*.jpg" -c:v libx264 -preset veryfast -crf 23 -pix_fmt yuv420p \
          "${timelapseDir}/$cam-$day.mp4" \
          && rm -rf "$dir"
      done
      find ${timelapseDir} -maxdepth 1 -name '*.mp4' -mtime +14 -delete
    '';
  };
in
{
  services.frigate = {
    enable = true;
    hostname = "localhost";
    vaapiDriver = "radeonsi";
    settings = {
      version = "0.17-0";
      mqtt.enabled = false;
      telemetry.version_check = false;

      ffmpeg.hwaccel_args = "preset-vaapi";
      # ponytail: CPU detection is enough for one 4 FPS substream; use ONNX/ROCm if measured load warrants it.
      detectors.cpu.type = "cpu";

      genai = {
        provider = "openai";
        api_key = "local";
        model = "camera-vlm";
        provider_options.context_size = 32768;
      };
      face_recognition = {
        enabled = true;
        model_size = "large";
      };
      semantic_search.enabled = true;

      objects = {
        track = [
          "person"
          "dog"
        ];
        filters.dog.threshold = 0.5;
        genai = {
          enabled = true;
          use_snapshot = true;
          objects = [
            "person"
            "dog"
          ];
          prompt = "Briefly describe the {label} and its activity in this security-camera event.";
        };
      };

      record = {
        enabled = true;
        alerts.retain.days = 1;
        detections.retain.days = 1;
      };
      snapshots = {
        enabled = true;
        retain.default = 1;
      };
      review.alerts.labels = [
        "person"
        "dog"
      ];
      review.genai.enabled = true;

      cameras.e1_zoom = {
        # Native HEVC needs a browser with hardware decode; the H.264 transcode plays everywhere.
        live.streams = {
          "4K" = "e1_zoom_live";
          "4K HEVC" = "e1_zoom";
        };
        ffmpeg.inputs = [
          {
            path = "rtsp://127.0.0.1:8554/e1_zoom";
            input_args = "preset-rtsp-restream";
            roles = [ "record" ];
          }
          {
            path = "rtsp://127.0.0.1:8554/e1_zoom_sub";
            input_args = "preset-rtsp-restream";
            roles = [ "detect" ];
          }
        ];
        detect = {
          enabled = true;
          fps = 4;
        };
        review.alerts.required_zones = [ "doorway" ];
        zones.doorway = {
          coordinates = "0.269,0.678,0.345,0.686,0.345,0.997,0.274,0.998";
          loitering_time = 0;
          friendly_name = "Doorway";
        };
        motion.mask = [
          "0.367,0,0.368,0.061,0.001,0.066,0,0.007"
          "0.824,0.936,0.822,1,0.994,1,0.992,0.944"
        ];
      };
    };
  };

  services.go2rtc = {
    enable = true;
    settings = {
      api.listen = "127.0.0.1:1984";
      ffmpeg.bin = "${config.services.frigate.settings.ffmpeg.path}/bin/ffmpeg";
      rtsp.listen = "127.0.0.1:8554";
      streams = {
        # go2rtc expands ${VAR} from the unit's EnvironmentFile when loading the config.
        e1_zoom = [
          "ffmpeg:http://10.0.40.10/flv?port=1935&app=bcs&stream=channel0_main.bcs&user=\${FRIGATE_E1_USER}&password=\${FRIGATE_E1_PASSWORD}#video=copy"
        ];
        e1_zoom_sub = [
          "ffmpeg:http://10.0.40.10/flv?port=1935&app=bcs&stream=channel0_ext.bcs&user=\${FRIGATE_E1_USER}&password=\${FRIGATE_E1_PASSWORD}#video=copy"
        ];
        e1_zoom_live = [
          "exec:${config.services.frigate.settings.ffmpeg.path}/bin/ffmpeg -hide_banner -v error -fflags nobuffer -flags low_delay -hwaccel vaapi -hwaccel_device /dev/dri/renderD128 -hwaccel_output_format vaapi -hwaccel_flags allow_profile_mismatch -rtsp_transport tcp -i rtsp://127.0.0.1:8554/e1_zoom -an -vf scale_vaapi=format=nv12 -c:v h264_vaapi -b:v 12M -maxrate 12M -bufsize 24M -g 40 -bf 0 -profile:v high -level:v 5.1 -user_agent ffmpeg/go2rtc -rtsp_transport tcp -f rtsp {output}"
        ];
      };
    };
  };

  environment.persistence."/keep".directories = [
    "/var/lib/frigate"
    # Frames included, so the 03:00 upgrade reboot doesn't clip the day.
    timelapseDir
  ];

  systemd.services.timelapse-grab = {
    description = "Grab one timelapse frame per camera";
    after = [ "go2rtc.service" ];
    wants = [ "go2rtc.service" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = lib.getExe timelapse-grab;
      # A hung RTSP grab must die before the next minutely tick.
      TimeoutStartSec = 50;
    };
  };

  systemd.timers.timelapse-grab = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "minutely";
      AccuracySec = "1s";
    };
  };

  systemd.services.timelapse-stitch = {
    description = "Stitch yesterday's timelapse frames into a video";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = lib.getExe timelapse-stitch;
    };
  };

  systemd.timers.timelapse-stitch = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "00:15";
      Persistent = true;
    };
  };

  systemd.services.frigate = {
    after = [ "llama-swap.service" ];
    wants = [ "llama-swap.service" ];
    environment.OPENAI_BASE_URL = "http://127.0.0.1:9292/v1";
  };

  systemd.services.go2rtc = {
    before = [ "frigate.service" ];
    requiredBy = [ "frigate.service" ];
    serviceConfig = {
      EnvironmentFile = [ config.age.secrets.frigate-camera-env.path ];
      # /dev/dri/renderD128 access for the VAAPI live-stream transcode
      SupplementaryGroups = [ "render" ];
      Restart = "on-failure";
    };
  };

  systemd.services.frigate-deep-describe = {
    description = "Nightly deep VLM re-description of Frigate events";
    after = [
      "frigate.service"
      "llama-swap.service"
    ];
    wants = [
      "frigate.service"
      "llama-swap.service"
    ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = lib.getExe frigate-deep-describe;
      DynamicUser = true;
      PrivateTmp = true;
    };
  };

  # 02:00: after the day's events, before the 03:00 auto-upgrade window.
  systemd.timers.frigate-deep-describe = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "02:00";
      Persistent = true;
    };
  };

  systemd.services.tailscale-serve-frigate = {
    description = "Expose Frigate as a Tailscale Service";
    after = [
      "tailscaled.service"
      "tailscale-auth.service"
      "frigate.service"
      "nginx.service"
    ];
    wants = [
      "tailscaled.service"
      "frigate.service"
      "nginx.service"
    ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${lib.getExe config.services.tailscale.package} serve --service=${service} --https=443 --yes http://127.0.0.1:80";
      ExecStop = "${lib.getExe config.services.tailscale.package} serve --service=${service} --https=443 off";
    };
  };
}
