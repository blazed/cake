input=$(cat)
model=$(jq -r '.model.display_name' <<<"$input")
cwd=$(jq -r '.workspace.current_dir' <<<"$input")
used=$(jq -r '(.context_window.used_percentage // 0) * (.context_window.context_window_size // 0) / 100 | floor' <<<"$input")
total=$(jq -r '.context_window.context_window_size // 0' <<<"$input")

if [[ "$cwd" == "$HOME" ]]; then
  dp='~'
elif [[ "$cwd" == "$HOME/"* ]]; then
  dp="~${cwd#"$HOME"}"
else
  dp="$cwd"
fi

if [ "$total" -ge 1000000 ]; then
  tk="$((total / 1000000))M"
else
  tk="$((total / 1000))k"
fi
ctx="$((used / 1000))k/${tk}"

vcs=''
if cd "$cwd" 2>/dev/null; then
  jji=$(jj log -r @ --no-graph -T "separate(' ', change_id.shortest(4), bookmarks.map(|b| b.name()).join(' '))" 2>/dev/null || true)
  if [ -n "$jji" ]; then
    vcs="jj:$jji"
  else
    vcs=$(git -c gc.auto=0 branch --show-current 2>/dev/null || true)
  fi
fi

if [ -n "$vcs" ]; then
  printf '\033[2m%s %s (%s) [%s]\033[0m' "$model" "$dp" "$vcs" "$ctx"
else
  printf '\033[2m%s %s [%s]\033[0m' "$model" "$dp" "$ctx"
fi
