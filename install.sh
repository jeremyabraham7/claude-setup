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

src="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)/skills/claude-setup"
if [ ! -d "$src" ]; then
  echo "Run this script from a clone of the repo (skills/claude-setup not found)." >&2
  exit 1
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
