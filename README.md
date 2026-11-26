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

Installing also applies the rules and settings right away. Options for `install.sh`:

- `--symlink` link instead of copy
- `--no-apply` install the skill only
- `-- <args>` pass args to `apply.sh`, e.g. `./install.sh -- --dry-run`

With curl: `curl -fsSL .../install.sh | bash -s -- --no-apply`.

## Usage

In Claude Code, run `/claude-setup`. The skill previews with `apply.sh --dry-run`, then applies.

You can also run the script directly, with no Claude involved:

```sh
bash ~/.claude/skills/claude-setup/apply.sh [options]
```

It does two things, both idempotent and non-interactive:

1. Puts every file in `skills/claude-setup/rules/` (sorted) into `~/.claude/CLAUDE.md` inside a marked block.
2. Deep-merges `settings.patch.json` into `~/.claude/settings.json` to turn off built-in commit and PR attribution (needs `jq` or `python3`).

Target dir is `${CLAUDE_DIR:-$HOME/.claude}`. Files it changes get a `<file>.bak.<UTC timestamp>` copy first.

| Flag | Effect |
| --- | --- |
| `--dry-run` | print diffs, write nothing; exit 10 if changes would be made |
| `--rules-only` | only CLAUDE.md |
| `--settings-only` | only settings.json |
| `--no-backup` | skip the `.bak` copies |
| `--quiet` | print only errors |
| `-h`, `--help` | usage |

Exit codes: `0` ok, `2` refused (malformed markers or invalid settings JSON, nothing changed), `3` missing dependency (no jq or python3), `10` dry-run found changes, `64` usage error.

Unattended or CI use, for example to detect drift and then fix it:

```sh
CLAUDE_DIR="$HOME/.claude" bash apply.sh --dry-run --quiet; rc=$?
[ "$rc" -eq 10 ] && CLAUDE_DIR="$HOME/.claude" bash apply.sh --quiet --no-backup
```

## Add a rule

Drop another `.md` file into `skills/claude-setup/rules/` and run `/claude-setup` or `apply.sh` again.

## What it touches

Rules live only inside a marked block in `CLAUDE.md`:

```
<!-- claude-setup:begin -->
...
<!-- claude-setup:end -->
```

Everything outside the markers is left alone, byte for byte. Re-running replaces the block. Existing settings keys are kept. If the markers are malformed (only one, duplicated, or out of order), it refuses and changes nothing.

## Tests

`bash tests/run.sh` (uses temp dirs only).

## License

MIT
