# claude-setup

A Claude Code skill that sets up a fresh install with baseline behavior rules and settings.

## Install

```sh
git clone https://github.com/jeremyabraham7/claude-setup.git && cd claude-setup && ./install.sh
```

Use `./install.sh --symlink` to link instead of copy, so `git pull` updates the skill. Re-running is safe.

Or install without cloning (it fetches the repo itself; `--symlink` is not available this way):

```sh
curl -fsSL https://raw.githubusercontent.com/jeremyabraham7/claude-setup/main/install.sh | bash
```

## Usage

In Claude Code, run:

```
/claude-setup
```

It will:

1. Put every file in `skills/claude-setup/rules/` into `~/.claude/CLAUDE.md`.
2. Merge `settings.patch.json` into `~/.claude/settings.json` (showing a diff first) to turn off built-in commit and PR attribution.
3. Report what changed.

## Add a rule

Drop another `.md` file into `skills/claude-setup/rules/` and run `/claude-setup` again.

## What it touches

Rules live only inside a marked block in `CLAUDE.md`:

```
<!-- claude-setup:begin -->
...
<!-- claude-setup:end -->
```

Everything outside the markers is left alone. Re-running replaces the block. Existing settings keys are kept.

## License

MIT
