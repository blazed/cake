{
  config,
  lib,
  pkgs,
  ...
}:
let
  service = "svc:frigate";
  demoImage = pkgs.fetchurl {
    url = "https://raw.githubusercontent.com/blakeblackshear/frigate/v0.17.2/docker/rockchip/COCO/subset/000000052891.jpg";
    hash = "sha256-5VuGoc2odBF7ob2FXjjbybVCe4QMNi1yMwAZZ27EekQ=";
  };
  demoVideo = pkgs.runCommand "frigate-demo.mp4" { nativeBuildInputs = [ pkgs.ffmpeg-headless ]; } ''
    ffmpeg -hide_banner -loglevel error \
      -f lavfi -i color=c=black:s=640x480:r=5:d=5 \
      -loop 1 -framerate 5 -t 15 -i ${demoImage} \
      -f lavfi -i color=c=black:s=640x480:r=5:d=5 \
      -filter_complex '[1:v]scale=640:480,setsar=1[demo];[0:v][demo][2:v]concat=n=3:v=1:a=0,format=yuv420p[v]' \
      -map '[v]' -c:v libx264 -preset veryfast -movflags +faststart "$out"
  '';
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

      # ponytail: CPU detection is enough for one 5 FPS demo; use ONNX/ROCm with the real camera if needed.
      detectors.cpu.type = "cpu";

      genai = {
        provider = "openai";
        api_key = "local";
        model = "camera-vlm";
        provider_options.context_size = 32768;
      };

      objects = {
        track = [ "dog" ];
        filters.dog.threshold = 0.5;
        genai = {
          enabled = true;
          use_snapshot = true;
          objects = [ "dog" ];
          prompt = "Briefly describe the {label} and its activity in this synthetic security-camera event.";
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
      review.alerts.labels = [ "dog" ];

      cameras.demo = {
        ffmpeg.inputs = [
          {
            path = toString demoVideo;
            input_args = [
              "-re"
              "-stream_loop"
              "-1"
            ];
            roles = [
              "detect"
              "record"
            ];
          }
        ];
        detect = {
          enabled = true;
          width = 640;
          height = 480;
          fps = 5;
        };
      };
    };
  };

  environment.persistence."/keep".directories = [ "/var/lib/frigate" ];

  systemd.services.frigate = {
    after = [ "llama-swap.service" ];
    wants = [ "llama-swap.service" ];
    environment.OPENAI_BASE_URL = "http://127.0.0.1:9292/v1";
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
