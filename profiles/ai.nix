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
      version = "251";
      src = pkgs.fetchFromGitHub {
        owner = "mostlygeek";
        repo = "llama-swap";
        tag = "v${version}";
        hash = "sha256-N769kY7zJ58gcrKrfbA7Wgxz2EnxktVWiN8MdiuYfQQ=";
        leaveDotGit = true;
        postFetch = ''
          cd "$out"
          git rev-parse HEAD > $out/COMMIT
          date -u -d "@$(git log -1 --pretty=%ct)" "+'%Y-%m-%dT%H:%M:%SZ'" > $out/SOURCE_DATE_EPOCH
          find "$out" -name .git -print0 | xargs -0 rm -rf
        '';
      };
      vendorHash = "sha256-MhR8B2+Yb/xqrTlIxaVHLoQf1eTOO49c65l72IAuZyU=";
      patches = (oa.patches or [ ]) ++ [ ../patches/llama-swap-v250-shell.patch ];
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
          sourceRoot = "${src.name}/${if lib.versionAtLeast version "251" then "ui" else "ui-svelte"}";
          npmDepsHash = "sha256-+J/C0yDjG0is5G5bNGfFY1ztA7dFqBind/VoS2mxT6s=";
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
        qwenMmproj = pkgs.fetchurl {
          url = "https://huggingface.co/ggml-org/Qwen3.8-27B-GGUF/resolve/main/mmproj-Qwen3.8-27B-Q8_0.gguf";
          hash = "sha256-LpaKavl8412JcYkLJXubftq/IK2RRQUB+lMWKhnuM+s=";
        };
        deepseekHereticLora = pkgs.fetchurl {
          url = "https://huggingface.co/MoriNoNushi/DeepSeek-V4-Flash-0731-heretic-abliterated-v2-GGUF-lora/resolve/main/ds4-flash-heretic-f4-t265-lora.gguf";
          hash = "sha256-NkI/bWN/zO5tDACkpPJcJV+1OCVFt2ASM0qW4hzU3lI=";
        };
        llama-cpp =
          (pkgs.llama-cpp.override {
            rocmSupport = true;
            blasSupport = true;
            cudaSupport = false;
            rocmGpuTargets = [ "gfx1151" ];
          }).overrideAttrs
            (oa: rec {
              version = "10631";
              src = pkgs.fetchFromGitHub {
                owner = "ggml-org";
                repo = "llama.cpp";
                tag = "b${version}";
                hash = "sha256-jkJvt2baD6z8WOHQf6V6ACG2CS63APwLO/4kXjqk3a4=";
                leaveDotGit = true;
                postFetch = ''
                  git -C "$out" rev-parse --short HEAD > $out/COMMIT
                  find "$out" -name .git -print0 | xargs -0 rm -rf
                '';
              };
              npmRoot = "tools/ui";
              npmDepsHash = "sha256-2Q7XhaLAArmviOLdQsNbYTfdyDE5pW9lR26cRHEVl9k=";

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
            batchSize ? 4096,
            ubatchSize ? 2048,
            sampling ? [ ],
            mtp ? false,
            flashAttention ? true,
            thinking ? true,
            chatTemplateFile ? null,
            lora ? null,
            mmproj ? null,
            vision ? false,
            tools ? false,
            name ? null,
            description ? null,
          }:
          {
            cmd = lib.concatStringsSep "\n" (
              [
                llama-server
                "--host ::1"
                "--hf-repo ${hf}"
                "--port \${PORT}"
              ]
              ++ lib.optionals (lora != null) [
                "--lora ${lora}"
              ]
              ++ lib.optionals (mmproj != null) [
                "--mmproj ${mmproj}"
              ]
              ++ [
                "--ctx-size ${toString ctx}"
                "--batch-size ${toString batchSize}"
                "--ubatch-size ${toString ubatchSize}"
                "--cache-reuse 256"
                "--threads 16"
                "--threads-batch 32"
                "--kv-unified"
                "-ngl 999"
                "-fa ${if flashAttention then "on" else "off"}"
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
            capabilities = {
              "in" = [ "text" ] ++ lib.optional vision "image";
              out = [ "text" ];
              context = ctx;
            }
            // lib.optionalAttrs tools {
              inherit tools;
            };
          }
          // lib.optionalAttrs (name != null) { inherit name; }
          // lib.optionalAttrs (description != null) { inherit description; };

      in
      {
        models = {
          "deepseek-v4-flash-0731:iq3" = mkModel {
            hf = "unsloth/DeepSeek-V4-Flash-0731-GGUF:UD-IQ3_XXS";
            name = "DeepSeek V4 Flash IQ3";
            description = "Stock DeepSeek V4 Flash at IQ3 quality.";
            tools = true;
            kv = "f16";
            ctx = 131072;
            sampling = deepseekSampling;
            # The GGUF chat template enables thinking by default; avoid passing the
            thinking = false;
          };
          "deepseek-v4-flash-0731-heretic:iq3" = mkModel {
            hf = "unsloth/DeepSeek-V4-Flash-0731-GGUF:UD-IQ3_XXS";
            name = "DeepSeek V4 Flash Heretic v2 IQ3";
            description = "DeepSeek V4 Flash with the conservative Heretic v2 LoRA.";
            lora = deepseekHereticLora;
            tools = true;
            kv = "f16";
            ctx = 131072;
            sampling = deepseekSampling;
            # Avoid the ROCm fused path that crashes while applying the rank-1 LoRA.
            flashAttention = false;
            # FA off needs smaller compute buffers on this GPU.
            batchSize = 1024;
            ubatchSize = 512;
            # The embedded template supports enable_thinking but enables no mode by default.
            thinking = false;
          };
          "qwen3.8-27b:q8" = mkModel {
            hf = "unsloth/Qwen3.8-27B-GGUF:Q8_0";
            name = "Qwen3.8 27B Q8";
            description = "Stock Qwen3.8 27B with image input support.";
            mmproj = qwenMmproj;
            vision = true;
            tools = true;
            kv = "q8_0";
            sampling = [
              "--temp 1.0"
              "--top-p 0.95"
              "--top-k 20"
              "--min-p 0.0"
            ];
            mtp = true;
          };
          "qwen3.8-27b:rvn-ara-q8" = mkModel {
            hf = "0bserverx/Qwen3.8-27B-Heretic-Abliterated-Uncensored-GGUF:RVN-Q8_0-multilingual";
            name = "Qwen3.8 27B RVN ARA Q8";
            description = "RVN ARA Qwen3.8 27B with image input support.";
            mmproj = qwenMmproj;
            vision = true;
            tools = true;
            kv = "q8_0";
            sampling = [
              "--temp 1.0"
              "--top-p 0.95"
              "--top-k 20"
              "--min-p 0.0"
            ];
          };
          "qwen3.8-27b:rvn-ara-q6" = mkModel {
            hf = "0bserverx/Qwen3.8-27B-Heretic-Abliterated-Uncensored-GGUF:RVN-Q6_K-multilingual";
            name = "Qwen3.8 27B RVN ARA Q6";
            description = "RVN ARA Qwen3.8 27B with image input support.";
            mmproj = qwenMmproj;
            vision = true;
            tools = true;
            kv = "f16";
            sampling = [
              "--temp 1.0"
              "--top-p 0.95"
              "--top-k 20"
              "--min-p 0.0"
            ];
          };
        };

        healthCheckTimeout = 7200;
        globalTTL = 3600;
        logTimeFormat = "rfc3339";
        logToStdout = "both";
        sendLoadingState = true;
        unloadTimeout = 60;
        groups = { };

        performance = {
          disabled = true;
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
    # The upstream module sets ProcSubset = "pid", which hides /proc/meminfo, /proc/stat
    # and /proc/loadavg - the performance monitor's gopsutil reads need them. Relax it so
    # system CPU/RAM/load metrics work (other processes stay hidden via ProtectProc).
    ProcSubset = lib.mkForce "all";
    Environment = [
      # rocm-smi (GPU backend for the performance monitor) is appended to PATH.
      "PATH=/run/current-system/sw/bin:${pkgs.rocmPackages.rocm-smi}/bin"
      "LD_LIBRARY_PATH=/run/opengl-driver/lib:/run/opengl-driver-32/lib"
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
