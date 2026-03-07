#!/usr/bin/env bash
set -euo pipefail

AI_NIX="profiles/ai.nix"
FAKE_HASH="sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="

extract_hash() {
  grep -oP 'got:\s+sha256-[^\s]+' | head -1 | grep -oP 'sha256-[^\s]+'
}

nix_build_file() {
  local tmpfile output
  tmpfile=$(mktemp /tmp/update-ai-XXXXXX.nix)
  cat > "$tmpfile"
  output=$(nix build --no-link --impure --expr "import $tmpfile" 2>&1 || true)
  rm -f "$tmpfile"
  echo "$output"
}

# --- llama.cpp ---

update_llama_cpp() {
  local current latest
  current=$(sed -n '/llama-cpp/,/llama-server/{s/.*version = "\([0-9]*\)".*/\1/p}' "$AI_NIX" | head -1)
  latest=$(curl -s "https://api.github.com/repos/ggml-org/llama.cpp/releases/latest" | jq -r '.tag_name' | sed 's/^b//')

  echo "llama.cpp: current=$current latest=$latest"
  if [ "$current" = "$latest" ]; then
    echo "llama.cpp: already up to date."
    return 0
  fi

  echo "llama.cpp: updating $current -> $latest..."

  local llama_cpp_src_expr
  llama_cpp_src_expr=$(cat <<NIX
let pkgs = import <nixpkgs> {};
in pkgs.fetchFromGitHub {
  owner = "ggml-org";
  repo = "llama.cpp";
  tag = "b${latest}";
  hash = "@HASH@";
  leaveDotGit = true;
  postFetch = ''
    git -C "\$out" rev-parse --short HEAD > \$out/COMMIT
    find "\$out" -name .git -print0 | xargs -0 rm -rf
  '';
}
NIX
  )

  # Get src hash
  echo "llama.cpp: fetching source hash..."
  local src_hash
  src_hash=$(echo "${llama_cpp_src_expr//@HASH@/$FAKE_HASH}" | nix_build_file | extract_hash || true)
  if [ -z "$src_hash" ]; then
    echo "ERROR: could not determine llama.cpp src hash"
    return 1
  fi
  echo "  src hash: $src_hash"

  # Get npmDepsHash (npm root is in tools/server/webui)
  echo "llama.cpp: fetching npm deps hash..."
  local npm_hash
  npm_hash=$(cat <<NIX | nix_build_file | extract_hash || true
let pkgs = import <nixpkgs> {};
    src = ${llama_cpp_src_expr//@HASH@/$src_hash};
in pkgs.fetchNpmDeps {
  inherit src;
  preBuild = "pushd tools/server/webui";
  hash = "$FAKE_HASH";
}
NIX
  )
  if [ -z "$npm_hash" ]; then
    echo "ERROR: could not determine llama.cpp npmDepsHash"
    return 1
  fi
  echo "  npmDepsHash: $npm_hash"

  # Apply changes using line-specific sed to avoid cross-contamination
  # Find the llama.cpp block boundaries
  local repo_line
  repo_line=$(grep -n 'repo = "llama.cpp"' "$AI_NIX" | cut -d: -f1)

  # Update version (last `version = "..."` before the repo line)
  local version_line
  version_line=$(head -n "$repo_line" "$AI_NIX" | grep -n "version = \"$current\"" | tail -1 | cut -d: -f1)
  sed -i "${version_line}s/version = \"$current\"/version = \"$latest\"/" "$AI_NIX"

  # Update src hash (first `hash = "sha256-..."` after the repo line)
  local src_hash_line
  src_hash_line=$(tail -n +"$repo_line" "$AI_NIX" | grep -n 'hash = "sha256-' | head -1 | cut -d: -f1)
  src_hash_line=$((repo_line + src_hash_line - 1))
  sed -i "${src_hash_line}s|hash = \"sha256-[^\"]*\"|hash = \"$src_hash\"|" "$AI_NIX"

  # Update npmDepsHash (first `npmDepsHash` after the repo line)
  local npm_hash_line
  npm_hash_line=$(tail -n +"$repo_line" "$AI_NIX" | grep -n 'npmDepsHash' | head -1 | cut -d: -f1)
  npm_hash_line=$((repo_line + npm_hash_line - 1))
  sed -i "${npm_hash_line}s|npmDepsHash = \"sha256-[^\"]*\"|npmDepsHash = \"$npm_hash\"|" "$AI_NIX"

  echo "llama.cpp: updated $current -> $latest"
}

# --- llama-swap ---

update_llama_swap() {
  local current latest
  current=$(sed -n '0,/repo = "llama-swap"/{s/.*version = "\([0-9]*\)".*/\1/p}' "$AI_NIX" | head -1)
  latest=$(curl -s "https://api.github.com/repos/mostlygeek/llama-swap/releases/latest" | jq -r '.tag_name' | sed 's/^v//')

  echo "llama-swap: current=$current latest=$latest"
  if [ "$current" = "$latest" ]; then
    echo "llama-swap: already up to date."
    return 0
  fi

  echo "llama-swap: updating $current -> $latest..."

  local llama_swap_src_expr
  llama_swap_src_expr=$(cat <<NIX
let pkgs = import <nixpkgs> {};
in pkgs.fetchFromGitHub {
  owner = "mostlygeek";
  repo = "llama-swap";
  tag = "v${latest}";
  hash = "@HASH@";
  leaveDotGit = true;
  postFetch = ''
    cd "\$out"
    git rev-parse HEAD > \$out/COMMIT
    date -u -d "@\$(git log -1 --pretty=%ct)" "+'%Y-%m-%dT%H:%M:%SZ'" > \$out/SOURCE_DATE_EPOCH
    find "\$out" -name .git -print0 | xargs -0 rm -rf
  '';
}
NIX
  )

  # Get src hash
  echo "llama-swap: fetching source hash..."
  local src_hash
  src_hash=$(echo "${llama_swap_src_expr//@HASH@/$FAKE_HASH}" | nix_build_file | extract_hash || true)
  if [ -z "$src_hash" ]; then
    echo "ERROR: could not determine llama-swap src hash"
    return 1
  fi
  echo "  src hash: $src_hash"

  # Get npmDepsHash
  echo "llama-swap: fetching npm deps hash..."
  local npm_hash
  npm_hash=$(cat <<NIX | nix_build_file | extract_hash || true
let pkgs = import <nixpkgs> {};
    src = ${llama_swap_src_expr//@HASH@/$src_hash};
in pkgs.fetchNpmDeps {
  src = "\${src}/ui-svelte";
  hash = "$FAKE_HASH";
}
NIX
  )
  if [ -z "$npm_hash" ]; then
    echo "ERROR: could not determine llama-swap npmDepsHash"
    return 1
  fi
  echo "  npmDepsHash: $npm_hash"

  # Get vendorHash
  echo "llama-swap: fetching vendor hash..."
  local vendor_hash
  vendor_hash=$(cat <<NIX | nix_build_file | extract_hash || true
let pkgs = import <nixpkgs> {};
    src = ${llama_swap_src_expr//@HASH@/$src_hash};
in (pkgs.buildGoModule {
  pname = "llama-swap-vendor";
  version = "${latest}";
  inherit src;
  vendorHash = "$FAKE_HASH";
}).goModules
NIX
  )
  if [ -z "$vendor_hash" ]; then
    echo "ERROR: could not determine llama-swap vendorHash"
    return 1
  fi
  echo "  vendorHash: $vendor_hash"

  # Apply changes using line-specific sed
  local repo_line
  repo_line=$(grep -n 'repo = "llama-swap"' "$AI_NIX" | cut -d: -f1)

  # Update version (last `version = "..."` before the repo line)
  local version_line
  version_line=$(head -n "$repo_line" "$AI_NIX" | grep -n "version = \"$current\"" | tail -1 | cut -d: -f1)
  sed -i "${version_line}s/version = \"$current\"/version = \"$latest\"/" "$AI_NIX"

  # Update src hash (first `hash = "sha256-..."` after repo line)
  local src_hash_line
  src_hash_line=$(tail -n +"$repo_line" "$AI_NIX" | grep -n 'hash = "sha256-' | head -1 | cut -d: -f1)
  src_hash_line=$((repo_line + src_hash_line - 1))
  sed -i "${src_hash_line}s|hash = \"sha256-[^\"]*\"|hash = \"$src_hash\"|" "$AI_NIX"

  # Update vendorHash (first `vendorHash` after repo line)
  local vendor_line
  vendor_line=$(tail -n +"$repo_line" "$AI_NIX" | grep -n 'vendorHash' | head -1 | cut -d: -f1)
  vendor_line=$((repo_line + vendor_line - 1))
  sed -i "${vendor_line}s|vendorHash = \"sha256-[^\"]*\"|vendorHash = \"$vendor_hash\"|" "$AI_NIX"

  # Update npmDepsHash (first `npmDepsHash` after repo line)
  local npm_line
  npm_line=$(tail -n +"$repo_line" "$AI_NIX" | grep -n 'npmDepsHash' | head -1 | cut -d: -f1)
  npm_line=$((repo_line + npm_line - 1))
  sed -i "${npm_line}s|npmDepsHash = \"sha256-[^\"]*\"|npmDepsHash = \"$npm_hash\"|" "$AI_NIX"

  echo "llama-swap: updated $current -> $latest"
}

update_llama_swap
update_llama_cpp
