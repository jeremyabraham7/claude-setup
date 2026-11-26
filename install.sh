#!/usr/bin/env bash
# Install the claude-setup skill into ~/.claude/skills/claude-setup.
# Usage: ./install.sh [--symlink]
# Set CLAUDE_DIR to override the target (default: $HOME/.claude).
set -euo pipefail

mode=copy
for arg in "$@"; do
  case "$arg" in
    --symlink) mode=symlink ;;
    -h|--help) echo "Usage: $0 [--symlink]"; exit 0 ;;
    *) echo "Unknown option: $arg" >&2; exit 1 ;;
  esac
done

repo_url="https://github.com/jeremyabraham7/claude-setup"
script="${BASH_SOURCE[0]:-}"
src=""
if [ -n "$script" ] && [ -f "$script" ]; then
  cand="$(cd "$(dirname "$script")" && pwd)/skills/claude-setup"
  [ -d "$cand" ] && src="$cand"
fi

if [ -z "$src" ]; then
  if [ "$mode" = symlink ]; then
    echo "--symlink needs a local clone of the repo; it cannot be used when the script is piped or run alone." >&2
    exit 1
  fi
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' EXIT
  echo "Fetching $repo_url ..."
  if command -v git >/dev/null 2>&1; then
    git clone --quiet --depth 1 "$repo_url" "$tmp/repo"
  else
    mkdir -p "$tmp/repo"
    curl -fsSL "$repo_url/archive/refs/heads/main.tar.gz" | tar -xz -C "$tmp/repo" --strip-components=1
  fi
  src="$tmp/repo/skills/claude-setup"
  [ -d "$src" ] || { echo "Download failed: skills/claude-setup not found." >&2; exit 1; }
fi

claude_dir="${CLAUDE_DIR:-$HOME/.claude}"
dest="$claude_dir/skills/claude-setup"
mkdir -p "$claude_dir/skills"
rm -rf "$dest"

if [ "$mode" = symlink ]; then
  ln -s "$src" "$dest"
else
  cp -R "$src" "$dest"
fi
echo "Installed claude-setup ($mode) -> $dest"
echo "Run /claude-setup in Claude Code to apply the rules."
