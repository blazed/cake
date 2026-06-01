{
  config,
  pkgs,
  lib,
  ...
}:
{
  services.llama-swap = {
    enable = true;
    package = pkgs.llama-swap.overrideAttrs (oa: rec {
      version = "222";
      src = pkgs.fetchFromGitHub {
        owner = "mostlygeek";
        repo = "llama-swap";
        tag = "v${version}";
        hash = "sha256-dROwL45tO4crAxIR0qml+q6viOovInHAMhHAW6nqRkE=";
        leaveDotGit = true;
        postFetch = ''
          cd "$out"
          git rev-parse HEAD > $out/COMMIT
          date -u -d "@$(git log -1 --pretty=%ct)" "+'%Y-%m-%dT%H:%M:%SZ'" > $out/SOURCE_DATE_EPOCH
          find "$out" -name .git -print0 | xargs -0 rm -rf
        '';
      };
      vendorHash = "sha256-b+RreafBMCWT/jbWTlXaiDRzA4DRe76WaCEbrfRxV/4=";
      postPatch = lib.optionalString (oa ? postPatch && oa.postPatch != null) oa.postPatch + ''
        substituteInPlace internal/process/process_command_forking_test.go \
          --replace-fail "#!/bin/bash" "#!${pkgs.bash}/bin/bash"
      '';
      preBuild = ''
        ldflags+=" -X main.commit=$(cat COMMIT)"
        ldflags+=" -X main.date=$(cat SOURCE_DATE_EPOCH)"

        rm -rf proxy/ui_dist internal/server/ui_dist
        cp -r ${passthru.ui}/ui_dist proxy/
        cp -r ${passthru.ui}/ui_dist internal/server/
      '';
      passthru = oa.passthru // {
        ui = pkgs.buildNpmPackage {
          pname = "llama-swap-ui";
          inherit version src;
          sourceRoot = "${src.name}/ui-svelte";
          npmDepsHash = "sha256-NJqEJ+XTdpPFtJJxP4CGu+JDUW7lKDcFgsixQJ3SXtQ=";
          postPatch = ''
            substituteInPlace vite.config.ts \
              --replace-fail "../internal/server/ui_dist" "${placeholder "out"}/ui_dist"
          '';
          postInstall = ''
            rm -rf $out/lib
          '';
        };
      };
    });
    port = 9292;
    listenAddress = "0.0.0.0";
    openFirewall = true;
    settings =
      let
        llama-cpp =
          (pkgs.llama-cpp.override {
            rocmSupport = true;
            blasSupport = true;
            cudaSupport = false;
            rocmGpuTargets = [ "gfx1151" ];
          }).overrideAttrs
            (oa: rec {
              version = "9451";
              src = pkgs.fetchFromGitHub {
                owner = "ggml-org";
                repo = "llama.cpp";
                tag = "b${version}";
                hash = "sha256-HKJsyvqOWC/xr8UIUgZQTSiA1/YlCIw9/YPmSZVGM10=";
                leaveDotGit = true;
                postFetch = ''
                  git -C "$out" rev-parse --short HEAD > $out/COMMIT
                  find "$out" -name .git -print0 | xargs -0 rm -rf
                '';
              };
              npmRoot = "tools/ui";
              npmDepsHash = "sha256-Iyg8FpcTKf2UYHuK7mA3cTAqVaLcQPcS0YCa5Qf01Gc=";

              cmakeFlags = (oa.cmakeFlags or [ ]) ++ [
                "-DGGML_NATIVE=ON"
                "-DGGML_HIP_ROCWMMA_FATTN=ON"
                "-DCMAKE_HIP_FLAGS=-I${pkgs.rocmPackages.rocwmma}/include"
              ];

              preConfigure = ''
                export NIX_ENFORCE_NO_NATIVE=0
                ${oa.preConfigure or ""}
              '';
            });
        llama-server = lib.getExe' llama-cpp "llama-server";
      in
      {
        models = {
          "qwen3.6:27b-mtp-q8" = {
            cmd = ''
              ${llama-server}
              -hf unsloth/Qwen3.6-27B-MTP-GGUF:UD-Q8_K_XL
              --port ''${PORT}
              --ctx-size 262144
              --batch-size 4096
              --ubatch-size 1024
              --cache-reuse 256
              --threads 16
              --kv-unified
              -ngl 999
              -fa on
              --cache-type-k q8_0
              --cache-type-v q8_0
              --no-mmap
              --temp 0.6
              --top-p 0.95
              --top-k 20
              --min-p 0.00
              --repeat-penalty 1.0
              --jinja
              --metrics
              --slots
              --spec-type draft-mtp
              --spec-draft-n-max 2
              --chat-template-kwargs '{"preserve_thinking":true}'
            '';
          };

          "qwen3.6:27b-mtp-q4" = {
            cmd = ''
              ${llama-server}
              -hf unsloth/Qwen3.6-27B-MTP-GGUF:UD-Q4_K_XL
              --port ''${PORT}
              --ctx-size 262144
              --batch-size 4096
              --ubatch-size 1024
              --threads 16
              --kv-unified
              -ngl 999
              -fa on
              --cache-type-k q8_0
              --cache-type-v q8_0
              --no-mmap
              --temp 0.6
              --top-p 0.95
              --top-k 20
              --min-p 0.00
              --repeat-penalty 1.0
              --jinja
              --metrics
              --slots
              --spec-type draft-mtp
              --spec-draft-n-max 2
              --chat-template-kwargs '{"preserve_thinking":true}'
            '';
          };

          "qwen3.6:35b-a3b-mtp-q4" = {
            cmd = ''
              ${llama-server}
              -hf unsloth/Qwen3.6-35B-A3B-MTP-GGUF:UD-Q4_K_XL
              --port ''${PORT}
              --ctx-size 262144
              --batch-size 4096
              --ubatch-size 1024
              --cache-reuse 256
              --threads 16
              --kv-unified
              -ngl 999
              -fa on
              --cache-type-k q8_0
              --cache-type-v q8_0
              --no-mmap
              --temp 0.6
              --top-p 0.95
              --top-k 20
              --min-p 0.00
              --repeat-penalty 1.0
              --jinja
              --metrics
              --slots
              --spec-type draft-mtp
              --spec-draft-n-max 2
              --chat-template-kwargs '{"preserve_thinking":true}'
            '';
          };

          "qwen3.6:35b-a3b-mtp-q8" = {
            cmd = ''
              ${llama-server}
              -hf unsloth/Qwen3.6-35B-A3B-MTP-GGUF:UD-Q8_K_XL
              --port ''${PORT}
              --ctx-size 262144
              --batch-size 4096
              --ubatch-size 1024
              --cache-reuse 256
              --threads 16
              --kv-unified
              -ngl 999
              -fa on
              --cache-type-k q8_0
              --cache-type-v q8_0
              --no-mmap
              --temp 0.6
              --top-p 0.95
              --top-k 20
              --min-p 0.00
              --repeat-penalty 1.0
              --jinja
              --metrics
              --slots
              --spec-type draft-mtp
              --spec-draft-n-max 2
              --chat-template-kwargs '{"preserve_thinking":true}'
            '';
          };

          "qwen3.6:27b-q8" = {
            cmd = ''
              ${llama-server}
              -hf unsloth/Qwen3.6-27B-GGUF:UD-Q8_K_XL
              --port ''${PORT}
              --ctx-size 262144
              --batch-size 4096
              --ubatch-size 1024
              --cache-reuse 256
              --threads 16
              --kv-unified
              -ngl 999
              -fa on
              --cache-type-k q8_0
              --cache-type-v q8_0
              --no-mmap
              --temp 0.6
              --top-p 0.95
              --top-k 20
              --min-p 0.00
              --repeat-penalty 1.0
              --jinja
              --metrics
              --slots
              --chat-template-kwargs '{"preserve_thinking":true}'
            '';
          };

          "qwen3.6:27b-q4" = {
            cmd = ''
              ${llama-server}
              -hf unsloth/Qwen3.6-27B-GGUF:UD-Q4_K_XL
              --port ''${PORT}
              --ctx-size 262144
              --batch-size 4096
              --ubatch-size 1024
              --threads 16
              --kv-unified
              -ngl 999
              -fa on
              --cache-type-k q8_0
              --cache-type-v q8_0
              --no-mmap
              --temp 0.6
              --top-p 0.95
              --top-k 20
              --min-p 0.00
              --repeat-penalty 1.0
              --jinja
              --metrics
              --slots
              --chat-template-kwargs '{"preserve_thinking":true}'
            '';
          };

          "qwen3.6:35b-a3b-q4" = {
            cmd = ''
              ${llama-server}
              -hf unsloth/Qwen3.6-35B-A3B-GGUF:UD-Q4_K_XL
              --port ''${PORT}
              --ctx-size 262144
              --batch-size 4096
              --ubatch-size 1024
              --cache-reuse 256
              --threads 16
              --kv-unified
              -ngl 999
              -fa on
              --cache-type-k q8_0
              --cache-type-v q8_0
              --no-mmap
              --temp 0.6
              --top-p 0.95
              --top-k 20
              --min-p 0.00
              --repeat-penalty 1.0
              --jinja
              --metrics
              --slots
              --chat-template-kwargs '{"preserve_thinking":true}'
            '';
          };

          "qwen3.6:35b-a3b-q8" = {
            cmd = ''
              ${llama-server}
              -hf unsloth/Qwen3.6-35B-A3B-GGUF:UD-Q8_K_XL
              --port ''${PORT}
              --ctx-size 262144
              --batch-size 4096
              --ubatch-size 1024
              --cache-reuse 256
              --threads 16
              --kv-unified
              -ngl 999
              -fa on
              --cache-type-k q8_0
              --cache-type-v q8_0
              --no-mmap
              --temp 0.6
              --top-p 0.95
              --top-k 20
              --min-p 0.00
              --repeat-penalty 1.0
              --jinja
              --metrics
              --slots
              --chat-template-kwargs '{"preserve_thinking":true}'
            '';
          };

          "gemma-4:31b-q6" = {
            cmd = ''
              ${llama-server}
              -hf unsloth/gemma-4-31B-it-GGUF:UD-Q6_K_XL
              --port ''${PORT}
              --ctx-size 200000
              --batch-size 4096
              --ubatch-size 1024
              --cache-reuse 256
              --threads 16
              --kv-unified
              -ngl 999
              -fa on
              --cache-type-k q8_0
              --cache-type-v q8_0
              --no-mmap
              --temp 1.0
              --top-p 0.95
              --top-k 64
              --min-p 0.01
              --repeat-penalty 1.0
              --jinja
              --metrics
              --slots
            '';
          };

          "gemma-4:26b-a4b-q6" = {
            cmd = ''
              ${llama-server}
              -hf unsloth/gemma-4-26B-A4B-it-GGUF:UD-Q6_K_XL
              --port ''${PORT}
              --ctx-size 200000
              --batch-size 4096
              --ubatch-size 1024
              --cache-reuse 256
              --threads 16
              --kv-unified
              -ngl 999
              -fa on
              --cache-type-k q8_0
              --cache-type-v q8_0
              --no-mmap
              --temp 1.0
              --top-p 0.95
              --top-k 64
              --min-p 0.01
              --repeat-penalty 1.0
              --jinja
              --metrics
              --slots
            '';
          };
        };

        healthCheckTimeout = 7200;
        ttl = 3600;

        groups = { };

        # Experimental system/GPU performance monitor (UI tab + Prometheus /metrics).
        # Enabled by default upstream; set the poll interval explicitly to avoid the 5s
        # default keeping the GPU out of low-power states. GPU stats come from rocm-smi
        # (added to the service PATH below); CPU/RAM/load need ProcSubset relaxed below.
        performance = {
          disabled = false;
          every = "15s";
        };
      };
  };

  systemd.services.tailscale-serve-llama-swap = {
    description = "Expose llama-swap over Tailscale HTTPS";
    after = [
      "tailscaled.service"
      "tailscale-auth.service"
      "llama-swap.service"
    ];
    wants = [
      "tailscaled.service"
      "llama-swap.service"
    ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${lib.getExe config.services.tailscale.package} serve --bg --https=443 http://127.0.0.1:9292";
      ExecStop = "${lib.getExe config.services.tailscale.package} serve --https=443 off";
    };
  };

  systemd.services.llama-swap.serviceConfig = {
    LimitMEMLOCK = "infinity";
    CacheDirectory = [
      "llama.cpp"
      "huggingface"
    ];
    # The upstream module sets ProcSubset = "pid", which hides /proc/meminfo, /proc/stat
    # and /proc/loadavg — the performance monitor's gopsutil reads need them. Relax it so
    # system CPU/RAM/load metrics work (other processes stay hidden via ProtectProc).
    ProcSubset = lib.mkForce "all";
    Environment = [
      # rocm-smi (GPU backend for the performance monitor) is appended to PATH.
      "PATH=/run/current-system/sw/bin:${pkgs.rocmPackages.rocm-smi}/bin"
      "LD_LIBRARY_PATH=/run/opengl-driver/lib:/run/opengl-driver-32/lib"
      "XDG_CACHE_HOME=/var/cache"
      # Strix Halo (gfx1151) ROCm tuning:
      # Force correct gfx1151 identification on recent kernels (else misdetected as gfx1100).
      "HSA_OVERRIDE_GFX_VERSION=11.5.1"
      # Avoid the buggy SDMA copy path on unified memory.
      "HSA_ENABLE_SDMA=0"
      # Use hipBLASLt GEMMs when loadable (rocBLAS falls back silently otherwise).
      "ROCBLAS_USE_HIPBLASLT=1"
    ];
  };
}
