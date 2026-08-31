{
  config,
  lib,
  ...
}:
let
  service = "svc:frigate";
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

  environment.persistence."/keep".directories = [ "/var/lib/frigate" ];

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
