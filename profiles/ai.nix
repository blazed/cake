{
  pkgs,
  lib,
  ...
}:
{
  services.llama-swap = {
    enable = true;
    package = pkgs.llama-swap.overrideAttrs (oa: rec {
      version = "213";
      src = pkgs.fetchFromGitHub {
        owner = "mostlygeek";
        repo = "llama-swap";
        tag = "v${version}";
        hash = "sha256-B3LI2VfsNDNwj2dkCa3KSEOaWQ/4BgcsDQj7xotCtEk=";
        leaveDotGit = true;
        postFetch = ''
          cd "$out"
          git rev-parse HEAD > $out/COMMIT
          date -u -d "@$(git log -1 --pretty=%ct)" "+'%Y-%m-%dT%H:%M:%SZ'" > $out/SOURCE_DATE_EPOCH
          find "$out" -name .git -print0 | xargs -0 rm -rf
        '';
      };
      vendorHash = "sha256-QysQ7YdwJcLTziwL25j73n3tQVvzVQIFxN4GkTU8JZg=";
      passthru = oa.passthru // {
        ui = pkgs.buildNpmPackage {
          pname = "llama-swap-ui";
          inherit version src;
          sourceRoot = "${src.name}/ui-svelte";
          npmDepsHash = "sha256-NJqEJ+XTdpPFtJJxP4CGu+JDUW7lKDcFgsixQJ3SXtQ=";
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
              version = "9172";
              src = pkgs.fetchFromGitHub {
                owner = "ggml-org";
                repo = "llama.cpp";
                tag = "b${version}";
                hash = "sha256-n7I3XJab5CoYq1q6F4oZlbtzItdJ+f7S8GbJeNDan+s=";
                leaveDotGit = true;
                postFetch = ''
                  git -C "$out" rev-parse --short HEAD > $out/COMMIT
                  find "$out" -name .git -print0 | xargs -0 rm -rf
                '';
              };
              npmDepsHash = "sha256-WaEePrEZ7O/7deP2KJhe0AwiSKYA8HOqETmMHUkmBe0=";

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
          "qwen3.6:35b-a3b-uncensored-hauhaucs-aggressive-q4" = {
            cmd = ''
              ${llama-server}
              -hf HauhauCS/Qwen3.6-35B-A3B-Uncensored-HauhauCS-Aggressive:Q4_K_M
              --port ''${PORT}
              --ctx-size 200000
              --batch-size 2048
              --ubatch-size 512
              --cache-reuse 256
              --threads 16
              --kv-unified
              -ngl 999
              -fa on
              --cache-type-k q8_0
              --cache-type-v q8_0
              --mlock
              --temp 0.6
              --top-p 0.95
              --top-k 20
              --min-p 0.00
              --repeat-penalty 1.0
              --jinja
              --metrics
              --slots
            '';
          };

          "qwen3.6:27b-q8" = {
            cmd = ''
              ${llama-server}
              -hf unsloth/Qwen3.6-27B-GGUF:UD-Q8_K_XL
              --port ''${PORT}
              --ctx-size 200000
              --batch-size 2048
              --ubatch-size 512
              --cache-reuse 256
              --threads 16
              --kv-unified
              -ngl 999
              -fa on
              --cache-type-k q8_0
              --cache-type-v q8_0
              --mlock
              --temp 0.6
              --top-p 0.95
              --top-k 20
              --min-p 0.00
              --repeat-penalty 1.0
              --jinja
              --metrics
              --slots
            '';
          };

          "qwen3.6:27b-q4" = {
            cmd = ''
              ${llama-server}
              -hf unsloth/Qwen3.6-27B-GGUF:UD-Q4_K_XL
              --port ''${PORT}
              --ctx-size 200000
              --batch-size 2048
              --ubatch-size 512
              --threads 16
              --kv-unified
              -ngl 999
              -fa on
              --cache-type-k q8_0
              --cache-type-v q8_0
              --mlock
              --temp 0.6
              --top-p 0.95
              --top-k 20
              --min-p 0.00
              --repeat-penalty 1.0
              --jinja
              --metrics
              --slots
            '';
          };

          "qwen3.6:35b-a3b-q4" = {
            cmd = ''
              ${llama-server}
              -hf unsloth/Qwen3.6-35B-A3B-GGUF:UD-Q4_K_XL
              --port ''${PORT}
              --ctx-size 200000
              --batch-size 2048
              --ubatch-size 512
              --cache-reuse 256
              --threads 16
              --kv-unified
              -ngl 999
              -fa on
              --cache-type-k q8_0
              --cache-type-v q8_0
              --mlock
              --temp 0.6
              --top-p 0.95
              --top-k 20
              --min-p 0.00
              --repeat-penalty 1.0
              --jinja
              --metrics
              --slots
            '';
          };

          "qwen3.6:35b-a3b-q8" = {
            cmd = ''
              ${llama-server}
              -hf unsloth/Qwen3.6-35B-A3B-GGUF:UD-Q8_K_XL
              --port ''${PORT}
              --ctx-size 200000
              --batch-size 2048
              --ubatch-size 512
              --cache-reuse 256
              --threads 16
              --kv-unified
              -ngl 999
              -fa on
              --cache-type-k q8_0
              --cache-type-v q8_0
              --mlock
              --temp 0.6
              --top-p 0.95
              --top-k 20
              --min-p 0.00
              --repeat-penalty 1.0
              --jinja
              --metrics
              --slots
            '';
          };

          "gemma-4:31b-q6" = {
            cmd = ''
              ${llama-server}
              -hf unsloth/gemma-4-31B-it-GGUF:UD-Q6_K_XL
              --port ''${PORT}
              --ctx-size 200000
              --batch-size 2048
              --ubatch-size 512
              --cache-reuse 256
              --threads 16
              --kv-unified
              -ngl 999
              -fa on
              --cache-type-k q8_0
              --cache-type-v q8_0
              --mlock
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
              --batch-size 2048
              --ubatch-size 512
              --cache-reuse 256
              --threads 16
              --kv-unified
              -ngl 999
              -fa on
              --cache-type-k q8_0
              --cache-type-v q8_0
              --mlock
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
