---
name: claude-setup
description: Set up a fresh Claude Code install with baseline behavior rules. Use when the user says "set up claude", "scaffold claude install", "/claude-setup", "apply my baseline rules", or asks to install or refresh baseline rules in ~/.claude/CLAUDE.md and settings.json.
---

# claude-setup

Applies baseline rules and settings to a Claude Code install. It is idempotent: running it again updates the managed block and changes nothing else.

Files in this skill's directory:

- `rules/*.md`: one file per rule
- `settings.patch.json`: settings to merge into `~/.claude/settings.json`

To add a rule, drop another `.md` file into `rules/`. It is picked up on the next run.

## Steps

### 1. Rules into CLAUDE.md

1. Read every `*.md` file in `rules/` (sorted by filename).
2. Build a managed block: the line `<!-- claude-setup:begin -->`, then each rule's content separated by a blank line, then the line `<!-- claude-setup:end -->`.
3. Edit `~/.claude/CLAUDE.md`:
   - If the file is missing, create it (and `~/.claude/` if needed) containing just the block.
   - If it contains the begin and end markers, replace everything between them (inclusive) with the new block.
   - Otherwise append the block at the end, after a blank line.
   - Never modify any content outside the markers. If only one marker is present, stop and ask the user.

### 2. Settings

1. Read `settings.patch.json`.
2. Deep-merge it into `~/.claude/settings.json`. Create the file as `{}` first if missing. Keep all existing keys; patch values win only for keys in the patch. The patch turns off built-in attribution with `attribution.commit`, `attribution.pr` (newer) and `includeCoAuthoredBy` (older). Keep all of them.
3. Show the user a diff of the change before writing. Write only if there is a change.
4. The result must stay valid JSON.

### 3. Report

Tell the user what changed: which rules were added, updated or unchanged in `CLAUDE.md`, and which settings keys were changed. If nothing changed, say so.
