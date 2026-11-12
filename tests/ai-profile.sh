#!/usr/bin/env bash
# Run with: bash tests/ai-profile.sh (requires Nix and jq; no builds or model downloads).
set -euo pipefail

repo=$(cd "$(dirname "$0")/.." && pwd)
nix eval --json --no-write-lock-file \
  "path:$repo#nixosConfigurations.margot.config.services.llama-swap.settings" \
  | jq -e '
    . as $settings
    # Removed as unused; guard against accidental reintroduction.
    | ([.models | keys[] | select(test("^(deepseek-|qwen3\\.8-flash-next|qwen3-14b|qwen3-vl-)"))] == [])
      and ($settings.models["qwen3.8-27b:q8"].cmd | contains("--spec-type draft-mtp"))
      and ($settings.models["qwen3.5-4b:camera-q8"].ttl == 0)
      and ($settings.models["qwen3.5-4b:camera-q8"].cmd | contains("--hf-repo unsloth/Qwen3.5-4B-GGUF:Q8_0"))
      and ($settings.models["qwen3.5-4b:camera-q8"].cmd | contains("--reasoning off"))
      and ($settings.models["qwen3.5-4b:camera-q8"].capabilities.in == ["text", "image"])
      and ($settings.groups.camera.persistent == true)
      and ($settings.groups.camera.members == ["qwen3.5-4b:camera-q8"])
      and ($settings.groups.camera.exclusive == false)
      and ($settings.hooks.on_startup.preload == ["qwen3.5-4b:camera-q8"])
      and ($settings.selectors["camera-vlm-deep"].targets == ["qwen3.8-27b:q8"])
      # Chat-only models: text capabilities without the tools key (no agentic use).
      and ($settings.models["gemma-4-12b:q8"].capabilities == {in: ["text"], out: ["text"], context: 131072})
      and ($settings.models["gemma-4-12b:q8"].cmd | contains("--hf-repo unsloth/gemma-4-12b-it-GGUF:Q8_0"))
      and ($settings.models["gemma-4-12b:q8"].cmd | contains("--reasoning-preserve") | not)
      # Nemotron 3.5 Bolt replaces Nemotron 3; Bolt E4B is text-only.
      and ([$settings.models | keys[] | select(startswith("nemotron-3-"))] == [])
      and ($settings.models["nemotron-3.5-bolt-e4b:q8"] as $m
        | ($m.capabilities == {in: ["text"], out: ["text"], context: 65536, tools: true})
          and ($m.cmd | contains("--hf-repo unsloth/NVIDIA-Nemotron-3.5-Bolt-E4B-GGUF:UD-Q8_K_XL"))
          and ($m.cmd | contains("--no-mmproj"))
          and ($m.cmd | contains("--spec-type draft-dflash")))
      and all(
        ["nemotron-3.5-bolt-74b-a9b:q4", "unsloth/NVIDIA-Nemotron-3.5-Bolt-74B-A9B-GGUF:UD-Q4_K_XL"],
        ["muse-glimmer-30b:q8", "unsloth/Muse-Glimmer-30B-GGUF:Q8_0"];
        .[1] as $repo
        | $settings.models[.[0]]
        | (.capabilities.in == ["text", "image"])
          and (.capabilities.tools == true)
          and (.cmd | contains("--hf-repo \($repo)"))
          and (.cmd | contains("--spec-type draft-dflash"))
          and (.cmd | contains("--no-mmproj") | not))
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
