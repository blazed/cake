{
  pkgs,
  lib,
  ...
}:
{
  services.llama-swap = {
    enable = true;
    package = pkgs.llama-swap.overrideAttrs (oa: rec {
      version = "199";
      src = pkgs.fetchFromGitHub {
        owner = "mostlygeek";
        repo = "llama-swap";
        tag = "v${version}";
        hash = "sha256-tAWXhfOWPLBuEgd+32CbuIkn1hN+4VI4xkyx7E2a81I=";
        leaveDotGit = true;
        postFetch = ''
          cd "$out"
          git rev-parse HEAD > $out/COMMIT
          date -u -d "@$(git log -1 --pretty=%ct)" "+'%Y-%m-%dT%H:%M:%SZ'" > $out/SOURCE_DATE_EPOCH
          find "$out" -name .git -print0 | xargs -0 rm -rf
        '';
      };
      vendorHash = "sha256-XiDYlw/byu8CWvg4KSPC7m8PGCZXtp08Y1velx4BR8U=";
      passthru = oa.passthru // {
        ui = pkgs.buildNpmPackage {
          pname = "llama-swap-ui";
          inherit version src;
          sourceRoot = "${src.name}/ui-svelte";
          npmDepsHash = "sha256-gTDsuWPLCWsPltioziygFmSQFdLqjkZpmmVWIWoZwoc=";
          postPatch = ''
            substituteInPlace vite.config.ts \
              --replace-fail "../proxy/ui_dist" "${placeholder "out"}/ui_dist"
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
          }).overrideAttrs
            (oa: rec {
              version = "8713";
              src = pkgs.fetchFromGitHub {
                owner = "ggml-org";
                repo = "llama.cpp";
                tag = "b${version}";
                hash = "sha256-wtC4gSgjy101/vJpL7zr3J/fgffKg+k2p/4E3L/fC9E=";
                leaveDotGit = true;
                postFetch = ''
                  git -C "$out" rev-parse --short HEAD > $out/COMMIT
                  find "$out" -name .git -print0 | xargs -0 rm -rf
                '';
              };
              npmDepsHash = "sha256-eeftjKt0FuS0Dybez+Iz9VTVMA4/oQVh+3VoIqvhVMw=";

              cmakeFlags = (oa.cmakeFlags or [ ]) ++ [
                "-DGGML_NATIVE=ON"
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
          "gemma-4:31b-q6" = {
            cmd = ''
              ${llama-server}
              -hf unsloth/gemma-4-31B-it-GGUF:UD-Q6_K_XL
              --port ''${PORT}
              --ctx-size 200000
              --batch-size 2048
              --ubatch-size 512
              --threads 16
              -ngl 999
              -fa on
              --cache-type-k bf16 --cache-type-v bf16
              --mlock
              --temp 1.0
              --top-p 0.95
              --top-k 64
              --min-p 0.01
              --repeat-penalty 1.0
              --jinja
            '';
          };

          "gemma-4:26b-a4b-q6" = {
            cmd = ''
              ${llama-server}
              -hf unsloth/gemma-4-26B-A4B-it-GGUF:UD-Q6_K_XL
              --port ''${PORT}
              --ctx-size 200000
              --batch-size 2048
              --ubatch-size 512
              --threads 16
              -ngl 999
              -fa on
              --cache-type-k bf16 --cache-type-v bf16
              --mlock
              --temp 1.0
              --top-p 0.95
              --top-k 64
              --min-p 0.01
              --repeat-penalty 1.0
              --jinja
            '';
          };

          "qwen3-coder-next:q4" = {
            cmd = ''
              ${llama-server}
              -hf unsloth/Qwen3-Coder-Next-GGUF:UD-Q4_K_XL
              --port ''${PORT}
              --ctx-size 200000
              --batch-size 2048
              --ubatch-size 512
              --threads 16
              -ngl 999
              -fa on
              --cache-type-k bf16 --cache-type-v bf16
              --mlock
              --temp 1.0
              --top-p 0.95
              --top-k 40
              --min-p 0.01
              --repeat-penalty 1.0
              --jinja
            '';
          };

          "nemotron-3-super:122b-a12b-q4" = {
            cmd = ''
              ${llama-server}
              -hf unsloth/NVIDIA-Nemotron-3-Super-120B-A12B-GGUF:UD-Q4_K_XL
              --port ''${PORT}
              --ctx-size 65536
              --batch-size 2048
              --ubatch-size 512
              --threads 16
              -ngl 999
              -fa on
              --cache-type-k q8_0 --cache-type-v q8_0
              --mlock
              --temp 1.0
              --top-p 1.0
              --min-p 0.01
              --special
              --jinja
            '';
          };

          "qwen3.5:27b-claude-4.6-opus-reasoning-distilled-q4" = {
            cmd = ''
              ${llama-server}
              -hf Jackrong/Qwen3.5-27B-Claude-4.6-Opus-Reasoning-Distilled-GGUF:Q4_K_M
              --port ''${PORT}
              --ctx-size 65536
              --batch-size 2048
              --ubatch-size 512
              --threads 16
              -ngl 999
              -fa on
              --cache-type-k bf16 --cache-type-v bf16
              --repeat-penalty 1.0
              --presence-penalty 0.0
              --mlock
              --jinja
            '';
          };

          "qwen3.5:27b-uncensored-aggressive-q4" = {
            cmd = ''
              ${llama-server}
              -hf HauhauCS/Qwen3.5-27B-Uncensored-HauhauCS-Aggressive:Q4_K_M
              --port ''${PORT}
              --ctx-size 65536
              --batch-size 2048
              --ubatch-size 512
              --threads 16
              -ngl 999
              -fa on
              --cache-type-k q8_0 --cache-type-v q8_0
              --presence-penalty 0.0
              --repeat-penalty 1.0
              --mlock
              --jinja
            '';
          };

          "qwen3.5:9b-q4" = {
            cmd = ''
              ${llama-server}
              -hf unsloth/Qwen3.5-9B-GGUF:UD-Q4_K_XL
              --port ''${PORT}
              --ctx-size 200000
              --batch-size 2048
              --ubatch-size 512
              --threads 16
              -ngl 999
              -fa on
              --cache-type-k q8_0 --cache-type-v q8_0
              --mlock
              --chat-template-kwargs '{"enable_thinking": true}'
              --presence-penalty 0.0
              --repeat-penalty 1.0
              --jinja
            '';
          };

          "qwen3.5:27b-q4" = {
            cmd = ''
              ${llama-server}
              -hf unsloth/Qwen3.5-27B-GGUF:UD-Q4_K_XL
              --port ''${PORT}
              --ctx-size 200000
              --batch-size 2048
              --ubatch-size 512
              --threads 16
              --temp 0.6
              --top-p 0.95
              --top-k 20
              --min-p 0.00
              --presence-penalty 0.0
              --repeat-penalty 1.0
              -ngl 999
              -fa on
              --cache-type-k bf16 --cache-type-v bf16
              --mlock
              --jinja
            '';
          };

          "qwen3.5:27b-q8" = {
            cmd = ''
              ${llama-server}
              -hf unsloth/Qwen3.5-27B-GGUF:UD-Q8_K_XL
              --port ''${PORT}
              --ctx-size 200000
              --batch-size 2048
              --ubatch-size 512
              --threads 16
              --temp 0.6
              --top-p 0.95
              --top-k 20
              --min-p 0.00
              --presence-penalty 0.0
              --repeat-penalty 1.0
              -ngl 999
              -fa on
              --cache-type-k bf16 --cache-type-v bf16
              --mlock
              --jinja
            '';
          };

          "qwen3.5:122b-a10b-q4" = {
            cmd = ''
              ${llama-server}
              -hf unsloth/Qwen3.5-122B-A10B-GGUF:UD-Q4_K_XL
              --port ''${PORT}
              --ctx-size 65536
              --batch-size 2048
              --ubatch-size 512
              --threads 16
              -ngl 999
              -fa on
              --cache-type-k q8_0 --cache-type-v q8_0
              --jinja
            '';
          };

          "qwen3.5:35b-a3b-q4" = {
            cmd = ''
              ${llama-server}
              -hf unsloth/Qwen3.5-35B-A3B-GGUF:UD-Q4_K_XL
              --port ''${PORT}
              --ctx-size 200000
              --batch-size 2048
              --ubatch-size 512
              --threads 16
              --presence-penalty 0.0
              --repeat-penalty 1.0
              -ngl 999
              -fa on
              --cache-type-k q8_0 --cache-type-v q8_0
              --mlock
              --jinja
            '';
          };

          # General use: --temp 1.0 --top-p 0.95, Tool-calling: --temp 0.7 --top-p 1.0
          "glm-4.7-flash:q4" = {
            cmd = ''
              ${llama-server}
              -hf unsloth/GLM-4.7-Flash-GGUF:UD-Q4_K_XL
              --port ''${PORT}
              --ctx-size 200000
              --batch-size 2048
              --ubatch-size 512
              --threads 16
              -ngl 999
              -fa on
              --cache-type-k q8_0 --cache-type-v q8_0
              --mlock
              --temp 1.0
              --top-p 0.95
              --min-p 0.01
              --repeat-penalty 1.0
              --jinja
            '';
          };

          "nemotron-3-nano:30b-q4" = {
            cmd = ''
              ${llama-server}
              -hf unsloth/Nemotron-3-Nano-30B-A3B-GGUF:UD-Q4_K_XL
              --port ''${PORT}
              --ctx-size 200000
              --batch-size 2048
              --ubatch-size 512
              --threads 16
              -ngl 999
              -fa on
              --cache-type-k q8_0 --cache-type-v q8_0
              --mlock
              --temp 1.0
              --top-p 1.0
              --min-p 0.01
              --special
              --jinja
            '';
          };

          "devstral-2:24b-q4" = {
            cmd = ''
              ${llama-server}
              -hf unsloth/Devstral-Small-2-24B-Instruct-2512-GGUF:UD-Q4_K_XL
              --port ''${PORT}
              --ctx-size 65536
              --batch-size 2048
              --ubatch-size 512
              --threads 16
              -ngl 999
              -fa on
              --cache-type-k q8_0 --cache-type-v q8_0
              --mlock
              --jinja
            '';
          };

          "devstral-2:24b-q8" = {
            cmd = ''
              ${llama-server}
              -hf unsloth/Devstral-Small-2-24B-Instruct-2512-GGUF:UD-Q8_K_XL
              --port ''${PORT}
              --ctx-size 65536
              --batch-size 2048
              --ubatch-size 512
              --threads 16
              -ngl 999
              -fa on
              --cache-type-k q8_0 --cache-type-v q8_0
              --mlock
              --jinja
            '';
          };

          "devstral-2:123b" = {
            cmd = ''
              ${llama-server}
              -hf unsloth/Devstral-2-123B-Instruct-2512-GGUF:UD-Q3_K_XL
              --port ''${PORT}
              --ctx-size 65536
              --batch-size 2048
              --ubatch-size 512
              --threads 16
              -ngl 999
              -fa on
              --cache-type-k q8_0 --cache-type-v q8_0
              --jinja
            '';
          };

          "gpt-oss:120b-derestricted" = {
            cmd = ''
              ${llama-server}
              -hf Calandracas/gpt-oss-120b-Derestricted-GGUF
              --hf-file gpt-oss-120B-Derestricted-Q4_K_M.gguf
              --port ''${PORT}
              --ctx-size 65536
              --batch-size 2048
              --ubatch-size 512
              --threads 16
              -ngl 999
              -fa on
              --cache-type-k q8_0 --cache-type-v q8_0
              --chat-template-kwargs '{"reasoning_effort": "high"}'
              --jinja
            '';
          };

          "qwen3-vl-thinking-abliterated:32b" = {
            cmd = ''
              ${llama-server}
              -hf huihui-ai/Huihui-Qwen3-VL-32B-Thinking-abliterated
              --hf-file GGUF/ggml-model-q8_0.gguf
              --mmproj-url https://huggingface.co/huihui-ai/Huihui-Qwen3-VL-32B-Thinking-abliterated/resolve/main/GGUF/mmproj-model-f16.gguf
              --port ''${PORT}
              --ctx-size 16384
              --batch-size 2048
              --ubatch-size 512
              --threads 16
              -ngl 999
              -fa on
              --cache-type-k q8_0 --cache-type-v q8_0
              --mlock
              --jinja
            '';
          };

          "glm-4.5-air:ud-q4_k_xl" = {
            cmd = ''
              ${llama-server}
              -hf unsloth/GLM-4.5-Air-GGUF
              --hf-file UD-Q4_K_XL/GLM-4.5-Air-UD-Q4_K_XL-00001-of-00002.gguf
              --port ''${PORT}
              --ctx-size 131072
              --batch-size 2048
              --ubatch-size 512
              --threads 16
              -ngl 999
              -fa on
              --cache-type-k q8_0 --cache-type-v q8_0
              --mlock
              --no-context-shift
              --swa-full
              --jinja
            '';
          };

          "qwen3-30b-a3b-abliterated" = {
            cmd = ''
              ${llama-server}
              --hf-repo mradermacher/Qwen3-30B-A3B-abliterated-erotic-i1-GGUF
              --port ''${PORT}
              --ctx-size 0
              --batch-size 4096
              --ubatch-size 2048
              --threads 16
              -ngl 999
              -fa on
              --cache-type-k q8_0 --cache-type-v q8_0
              --mlock
              --jinja
            '';
          };
        };

        healthCheckTimeout = 7200;
        ttl = 3600;

        groups = {
          embedding = {
            persistent = true;
            swap = false;
            exclusive = false;
            members = [ "embeddinggemma:300m" ];
          };
        };

      };
  };

  systemd.services.llama-swap.serviceConfig = {
    LimitMEMLOCK = "infinity";
    CacheDirectory = [
      "llama.cpp"
      "huggingface"
    ];
    Environment = [
      "PATH=/run/current-system/sw/bin"
      "LD_LIBRARY_PATH=/run/opengl-driver/lib:/run/opengl-driver-32/lib"
      "XDG_CACHE_HOME=/var/cache"
    ];
  };
}
