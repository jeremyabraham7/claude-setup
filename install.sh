#!/usr/bin/env bash
# Install the claude-setup skill into ~/.claude/skills/claude-setup.
# Usage: ./install.sh [--symlink] [--no-apply] [-- <apply.sh args>]
# After installing, runs the skill's apply.sh unless --no-apply is given.
# Args after "--" are passed to apply.sh (e.g. ./install.sh -- --dry-run).
# Set CLAUDE_DIR to override the target (default: $HOME/.claude).
set -euo pipefail

mode=copy
apply=1
apply_args=()
while [ $# -gt 0 ]; do
  case "$1" in
    --symlink) mode=symlink ;;
    --no-apply) apply=0 ;;
    --) shift; apply_args=("$@"); break ;;
    -h|--help) echo "Usage: $0 [--symlink] [--no-apply] [-- <apply.sh args>]"; exit 0 ;;
    *) echo "Unknown option: $1" >&2; exit 64 ;;
  esac
  shift
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
if [ "$apply" = 1 ]; then
  CLAUDE_DIR="$claude_dir" bash "$dest/apply.sh" ${apply_args[@]+"${apply_args[@]}"}
else
  echo "Skipped apply. Run /claude-setup in Claude Code, or: bash $dest/apply.sh"
fi
