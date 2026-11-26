---
name: claude-setup
description: Set up a fresh Claude Code install with baseline behavior rules. Use when the user says "set up claude", "scaffold claude install", "/claude-setup", "apply my baseline rules", or asks to install or refresh baseline rules in ~/.claude/CLAUDE.md and settings.json.
---

# claude-setup

This skill applies baseline rules and settings by running a script. Do not edit `CLAUDE.md` or `settings.json` by hand.

`apply.sh` in this skill's directory does all the work:

- Puts every `rules/*.md` file into a managed block in `~/.claude/CLAUDE.md` (between `<!-- claude-setup:begin -->` and `<!-- claude-setup:end -->`). Content outside the markers is never touched.
- Deep-merges `settings.patch.json` into `~/.claude/settings.json`.
- Writes a timestamped `.bak` of any file it changes.

To add a rule, drop another `.md` file into `rules/`.

## Steps

1. Preview: run `bash <skill dir>/apply.sh --dry-run` and show the user the diff. Exit 0 means nothing to do, exit 10 means changes would be made.
2. Apply: run `bash <skill dir>/apply.sh`.
3. Report the per-file result lines (created / updated / unchanged) and mention any backups created.

If `apply.sh` fails (exit 2: malformed markers or invalid settings JSON; exit 3: neither jq nor python3 is installed), report the error message and stop. Do not hand-edit the files to work around it.
