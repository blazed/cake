{
  pkgs,
  lib,
  ...
}:
{
  services.llama-swap = {
    enable = true;
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
            (oa: {
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
          "nemotron-3-nano:30b-q4" = {
            cmd = ''
              ${llama-server}
              -hf unsloth/Nemotron-3-Nano-30B-A3B-GGUF:UD-Q4_K_XL
              --port ''${PORT}
              --ctx-size 65536
              --batch-size 2048
              --ubatch-size 512
              --threads 1
              --jinja
            '';
          };

          "devstral-2:24b-q4" = {
            cmd = ''
              ${llama-server}
              -hf unsloth/Devstral-Small-2-24B-Instruct-2512-GGUF:UD-Q4_K_XL
              --port ''${PORT}
              --ctx-size 65536
              --jinja
            '';
          };

          "devstral-2:24b-q8" = {
            cmd = ''
              ${llama-server}
              -hf unsloth/Devstral-Small-2-24B-Instruct-2512-GGUF:UD-Q8_K_XL
              --port ''${PORT}
              --ctx-size 65536
              --jinja
            '';
          };

          "devstral-2:123b" = {
            cmd = ''
              ${llama-server}
              -hf unsloth/Devstral-2-123B-Instruct-2512-GGUF:UD-Q3_K_XL
              --port ''${PORT}
              --ctx-size 65536
              --batch-size 512
              --ubatch-size 512
              --split-mode layer
              --tensor-split 1.3,3
              --threads 8
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
              --batch-size 512
              --ubatch-size 512
              --split-mode layer
              --tensor-split 1.3,3
              --n-cpu-moe 24
              --threads 8
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
              --threads 1
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
              --tensor-split 28,20
              --n-cpu-moe 20
              --no-mmap
              --no-context-shift
              --swa-full
              --threads 8
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
              --threads 1
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
    CacheDirectory = "llama.cpp";
    Environment = [
      "PATH=/run/current-system/sw/bin"
      "LD_LIBRARY_PATH=/run/opengl-driver/lib:/run/opengl-driver-32/lib"
      "XDG_CACHE_HOME=/var/cache"
    ];
  };
}
