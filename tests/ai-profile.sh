#!/usr/bin/env bash
# Run with: bash tests/ai-profile.sh (requires Nix and jq; no builds or model downloads).
set -euo pipefail

repo=$(cd "$(dirname "$0")/.." && pwd)
nix eval --json --no-write-lock-file \
  "path:$repo#nixosConfigurations.margot.config.services.llama-swap.settings" \
  | jq -e '
    . as $settings
    | .models["qwen3.8-flash-next:q4"] as $model
    | ($model.cmd | split("\n")) as $args
    | ([
        "--hf-repo unsloth/Qwen3.8-Flash-Next-GGUF:UD-Q4_K_XL",
        "--ctx-size 131072",
        "--batch-size 2048",
        "--ubatch-size 512",
        "--parallel 1",
        "--cache-ram 2048",
        "--cache-type-k f16",
        "--cache-type-v f16",
        "--load-mode dio",
        "--lazy-mode auto",
        "--spec-type ngram-mod",
        "--spec-ngram-mod-n-match 24",
        "--spec-ngram-mod-n-min 48",
        "--spec-ngram-mod-n-max 64",
        "--temp 1.0",
        "--top-p 0.95",
        "--top-k 20",
        "--min-p 0.0",
        "--reasoning-preserve"
      ] - $args == [])
      and ($model.capabilities == {in: ["text", "image"], out: ["text"], context: 131072, tools: true})
      and (all($args[]; startswith("--spec-draft") | not))
      and ($args | index("--spec-type draft-mtp") | not)
      and (all($args[]; startswith("--mmproj") or startswith("--chat-template-file") | not))
      and ($settings.models["qwen3.8-27b:q8"].cmd | contains("--spec-type draft-mtp"))
      and ($settings.models["qwen3-vl-4b:camera-q8"].ttl == 0)
      and ($settings.groups.camera.persistent == true)
      and ($settings.groups.camera.exclusive == false)
      and ($settings.hooks.on_startup.preload == ["qwen3-vl-4b:camera-q8"])
      and ($settings.selectors["camera-vlm-deep"].targets == ["qwen3.8-27b:q8"])
      # Chat-only models: text capabilities without the tools key (no agentic use).
      and ($settings.models["gemma-4-12b:q8"].capabilities == {in: ["text"], out: ["text"], context: 131072})
      and ($settings.models["gemma-4-12b:q8"].cmd | contains("--hf-repo unsloth/gemma-4-12b-it-GGUF:Q8_0"))
      and ($settings.models["gemma-4-12b:q8"].cmd | contains("--reasoning-preserve") | not)
      # Diffusion uses its own backend, shares the interactive swap group,
      # and must not disturb the persistent camera worker.
      and (
        $settings.models["qwen-image-2.1:q4"] as $image
        | ($image.cmd | split("\n")) as $imageArgs
        | ($imageArgs[0] | endswith("/bin/sd-server"))
          and ([
            "--listen-ip 127.0.0.1",
            "--listen-port ${PORT}",
            "--max-vram 24",
            "--vae-tiling",
            "--threads 8",
            "--width 1024",
            "--height 1024",
            "--batch-count 1",
            "--steps 20",
            "--cfg-scale 6.0",
            "--sampling-method euler",
            "--seed -1"
          ] - $imageArgs == [])
          and ($image.cmd | test("--diffusion-model /nix/store/[^\\n]+-qwen-image-2\\.1-Q4_K_M\\.gguf"))
          and ($image.cmd | test("--llm /nix/store/[^\\n]+-Qwen3-VL-8B-Instruct-UD-Q4_K_XL\\.gguf"))
          and ($image.cmd | test("--llm_vision /nix/store/[^\\n]+-mmproj-F16\\.gguf"))
          and ($image.cmd | test("--vae /nix/store/[^\\n]+-qwen_image_2\\.1_vae_bf16\\.safetensors"))
          and (all($imageArgs[]; startswith("--flow-shift") or startswith("--hf-repo") | not))
          and ($image.proxy == "http://127.0.0.1:${PORT}")
          and ($image.checkEndpoint == "/v1/models")
          and ($image.ttl == 300)
          and ($image.concurrencyLimit == 1)
          and ($image.sendLoadingState == false)
          and ($image.filters.setParams.n == 1)
          and ($image.capabilities == {in: ["text", "image"], out: ["image"]})
          and (all($settings.groups[]; .members | index("qwen-image-2.1:q4") | not))
      )
  ' > /dev/null

echo 'AI profile checks passed'
