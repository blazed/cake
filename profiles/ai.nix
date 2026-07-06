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
      version = "235";
      src = pkgs.fetchFromGitHub {
        owner = "mostlygeek";
        repo = "llama-swap";
        tag = "v${version}";
        hash = "sha256-paS4B3PQV2B98rZTi3j2YUiJkvhpDv+jTsNLdwgsGC8=";
        leaveDotGit = true;
        postFetch = ''
          cd "$out"
          git rev-parse HEAD > $out/COMMIT
          date -u -d "@$(git log -1 --pretty=%ct)" "+'%Y-%m-%dT%H:%M:%SZ'" > $out/SOURCE_DATE_EPOCH
          find "$out" -name .git -print0 | xargs -0 rm -rf
        '';
      };
      vendorHash = "sha256-is8pm5g27in/LraLVJUzsa7EPqs+C3qzY8OQ/DXe98A=";
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
          npmDepsHash = "sha256-cAdFKDhmyaYCoKqSYEuAhu29rBxs7i8uTmU2SHwTLnY=";
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
              version = "9892";
              src = pkgs.fetchFromGitHub {
                owner = "ggml-org";
                repo = "llama.cpp";
                tag = "b${version}";
                hash = "sha256-De04DT1GG69Vo39s3w75PhIhOGpCEwr5xsMlXzSPjzc=";
                leaveDotGit = true;
                postFetch = ''
                  git -C "$out" rev-parse --short HEAD > $out/COMMIT
                  find "$out" -name .git -print0 | xargs -0 rm -rf
                '';
              };
              npmRoot = "tools/ui";
              npmDepsHash = "sha256-X1DZgmhS/zHTqDT5zq0kywwntthcJ9vRXeqyO3zz6UU=";

              cmakeFlags = (oa.cmakeFlags or [ ]) ++ [
                "-DGGML_NATIVE=ON"
                "-DGGML_HIP_ROCWMMA_FATTN=ON"
                "-DGGML_HIP_NO_VMM=ON"
                "-DGGML_HIP_MMQ_MFMA=ON"
                "-DCMAKE_HIP_FLAGS=-I${pkgs.rocmPackages.rocwmma}/include"
              ];

              preConfigure = ''
                export NIX_ENFORCE_NO_NATIVE=0
                ${oa.preConfigure or ""}
              '';
            });
        llama-server = lib.getExe' llama-cpp "llama-server";

        qwenSampling = [
          "--temp 0.6"
          "--top-p 0.95"
          "--top-k 20"
          "--min-p 0.00"
        ];
        gemmaSampling = [
          "--temp 1.0"
          "--top-p 0.95"
          "--top-k 64"
          "--min-p 0.01"
        ];

        # KV dtype convention: q8 weights keep q8_0/q8_0 (max-context memory saving);
        # q4/q6 weights use f16/f16 (f16 avoids the severe long-context slowdown that
        # quantized V cache causes on gfx1151).
        mkModel =
          {
            hf,
            kv,
            ctx ? 262144,
            sampling ? qwenSampling,
            mtp ? false,
            thinking ? true,
          }:
          {
            cmd = lib.concatStringsSep "\n" (
              [
                llama-server
                "-hf ${hf}"
                "--port \${PORT}"
                "--ctx-size ${toString ctx}"
                "--batch-size 4096"
                "--ubatch-size 2048"
                "--cache-reuse 256"
                "--threads 16"
                "--threads-batch 32"
                "--kv-unified"
                "-ngl 999"
                "-fa on"
                "--cache-type-k ${kv}"
                "--cache-type-v ${kv}"
                "--no-mmap"
                "--direct-io"
              ]
              ++ sampling
              ++ [
                "--repeat-penalty 1.0"
                "--jinja"
                "--metrics"
                "--slots"
              ]
              ++ lib.optionals mtp [
                "--spec-type draft-mtp"
                "--spec-draft-n-max 2"
              ]
              ++ lib.optionals thinking [
                "--chat-template-kwargs '{\"preserve_thinking\":true}'"
              ]
            );
          };
      in
      {
        models = {
          "qwen3.6:27b-mtp-q8" = mkModel {
            hf = "unsloth/Qwen3.6-27B-MTP-GGUF:UD-Q8_K_XL";
            kv = "q8_0";
            mtp = true;
          };
          "qwen3.6:27b-mtp-q4" = mkModel {
            hf = "unsloth/Qwen3.6-27B-MTP-GGUF:UD-Q4_K_XL";
            kv = "f16";
            mtp = true;
          };
          "qwen3.6:35b-a3b-mtp-q4" = mkModel {
            hf = "unsloth/Qwen3.6-35B-A3B-MTP-GGUF:UD-Q4_K_XL";
            kv = "f16";
            mtp = true;
          };
          "qwen3.6:35b-a3b-mtp-q8" = mkModel {
            hf = "unsloth/Qwen3.6-35B-A3B-MTP-GGUF:UD-Q8_K_XL";
            kv = "q8_0";
            mtp = true;
          };
          "qwen3.6:27b-q8" = mkModel {
            hf = "unsloth/Qwen3.6-27B-GGUF:UD-Q8_K_XL";
            kv = "q8_0";
          };
          "qwen3.6:27b-q4" = mkModel {
            hf = "unsloth/Qwen3.6-27B-GGUF:UD-Q4_K_XL";
            kv = "f16";
          };
          "qwen3.6:35b-a3b-q4" = mkModel {
            hf = "unsloth/Qwen3.6-35B-A3B-GGUF:UD-Q4_K_XL";
            kv = "f16";
          };
          "qwen3.6:35b-a3b-q8" = mkModel {
            hf = "unsloth/Qwen3.6-35B-A3B-GGUF:UD-Q8_K_XL";
            kv = "q8_0";
          };
          "gemma-4:31b-q6" = mkModel {
            hf = "unsloth/gemma-4-31B-it-GGUF:UD-Q6_K_XL";
            kv = "f16";
            ctx = 200000;
            sampling = gemmaSampling;
            thinking = false;
          };
          "gemma-4:26b-a4b-q6" = mkModel {
            hf = "unsloth/gemma-4-26B-A4B-it-GGUF:UD-Q6_K_XL";
            kv = "f16";
            ctx = 200000;
            sampling = gemmaSampling;
            thinking = false;
          };
        };

        healthCheckTimeout = 7200;
        globalTTL = 3600;
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
    # and /proc/loadavg - the performance monitor's gopsutil reads need them. Relax it so
    # system CPU/RAM/load metrics work (other processes stay hidden via ProtectProc).
    ProcSubset = lib.mkForce "all";
    Environment = [
      # rocm-smi (GPU backend for the performance monitor) is appended to PATH.
      "PATH=/run/current-system/sw/bin:${pkgs.rocmPackages.rocm-smi}/bin"
      "LD_LIBRARY_PATH=/run/opengl-driver/lib:/run/opengl-driver-32/lib"
      "XDG_CACHE_HOME=/var/cache"
      # Let ROCm allocate from the full unified-memory/GTT pool on this APU.
      "GGML_CUDA_ENABLE_UNIFIED_MEMORY=1"
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
