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
  ' > /dev/null

echo 'AI profile checks passed'
