{
  config,
  pkgs,
  lib,
  ...
}:
let
  port = 9292;
  service = "svc:ai";
in
{
  services.llama-swap = {
    enable = true;
    package = pkgs.llama-swap.overrideAttrs (oa: rec {
      version = "247";
      src = pkgs.fetchFromGitHub {
        owner = "mostlygeek";
        repo = "llama-swap";
        tag = "v${version}";
        hash = "sha256-YnawuBPZMv7oc0CNEIEQAGg8Pr/0ltskCDXJvLF+VPc=";
        leaveDotGit = true;
        postFetch = ''
          cd "$out"
          git rev-parse HEAD > $out/COMMIT
          date -u -d "@$(git log -1 --pretty=%ct)" "+'%Y-%m-%dT%H:%M:%SZ'" > $out/SOURCE_DATE_EPOCH
          find "$out" -name .git -print0 | xargs -0 rm -rf
        '';
      };
      vendorHash = "sha256-MhR8B2+Yb/xqrTlIxaVHLoQf1eTOO49c65l72IAuZyU=";
      tags = (oa.tags or [ ]) ++ [ "embed_ui" ];
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
          npmDepsHash = "sha256-6MPXQtmaz97D9PUU2Nn5DH/2HZNP/rnAWVSck/FiCyk=";
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
    inherit port;
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
              version = "10298";
              src = pkgs.fetchFromGitHub {
                owner = "ggml-org";
                repo = "llama.cpp";
                tag = "b${version}";
                hash = "sha256-mWqnszli9ZMWIKpyt2rxJLeVKa7/D3WLjKuaPkNqvQ4=";
                leaveDotGit = true;
                postFetch = ''
                  git -C "$out" rev-parse --short HEAD > $out/COMMIT
                  find "$out" -name .git -print0 | xargs -0 rm -rf
                '';
              };
              npmRoot = "tools/ui";
              npmDepsHash = "sha256-FHvd2bMvBc9EXrJEzu8EN78oUVSLcOKYCc0232V+L4A=";

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
        deepseekSampling = [
          "--temp 1.0"
          "--top-p 0.95"
          "--min-p 0.0"
        ];

        # KV dtype convention: q8 weights keep q8_0/q8_0 (max-context memory saving);
        # q4/q6 weights use f16/f16 (f16 avoids the severe long-context slowdown that
        # quantized V cache causes on gfx1151).
        mkModel =
          {
            hf,
            kv,
            ctx ? 262144,
            sampling ? [ ],
            mtp ? false,
            thinking ? true,
            chatTemplateFile ? null,
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
                "--load-mode dio"
              ]
              ++ sampling
              ++ [
                "--repeat-penalty 1.0"
                "--jinja"
                "--metrics"
                "--slots"
              ]
              ++ lib.optionals (chatTemplateFile != null) [
                "--chat-template-file ${chatTemplateFile}"
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
          "deepseek-v4-flash-0731:iq3" = mkModel {
            hf = "unsloth/DeepSeek-V4-Flash-0731-GGUF:UD-IQ3_XXS";
            kv = "f16";
            ctx = 131072;
            sampling = deepseekSampling;
            # The GGUF chat template enables thinking by default; avoid passing the
            thinking = false;
          };
          "deepseek-v4-flash-0731-abliterated:q2" = mkModel {
            hf = "huihui-ai/Huihui-DeepSeek-V4-Flash-0731-abliterated-GGUF";
            kv = "f16";
            ctx = 131072;
            sampling = deepseekSampling;
            # The embedded template supports enable_thinking but enables no mode by default.
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
    description = "Expose llama-swap as a Tailscale Service";
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
      ExecStart = "${lib.getExe config.services.tailscale.package} serve --service=${service} --https=443 --yes http://127.0.0.1:${toString port}";
      ExecStop = "${lib.getExe config.services.tailscale.package} serve --service=${service} --https=443 off";
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
