#!/usr/bin/env bash
# Apply claude-setup rules and settings to a Claude Code config dir.
# Deterministic and non-interactive. See --help.
set -euo pipefail
export LC_ALL=C

BEGIN='<!-- claude-setup:begin -->'
END='<!-- claude-setup:end -->'

usage() {
  cat <<'USAGE'
Usage: apply.sh [options]

Merge the rules in rules/*.md into a managed block in CLAUDE.md and deep-merge
settings.patch.json into settings.json. Target dir: ${CLAUDE_DIR:-$HOME/.claude}

Options:
  --dry-run         Print diffs, write nothing. Exit 10 if changes would be
                    made, 0 if there is nothing to do.
  --rules-only      Only touch CLAUDE.md.
  --settings-only   Only touch settings.json.
  --no-backup       Do not write <file>.bak.<UTC timestamp> before changes.
  --quiet           Print only errors.
  -h, --help        Show this help.

Exit codes: 0 ok, 2 refused (malformed markers or invalid JSON),
            3 missing dependency (need jq or python3), 10 dry-run drift,
            64 usage error.
USAGE
}

err() { printf 'claude-setup: %s\n' "$*" >&2; }

dry=0 quiet=0 backup=1 do_rules=1 do_settings=1 only_r=0 only_s=0
for arg in "$@"; do
  case "$arg" in
    --dry-run) dry=1 ;;
    --rules-only) only_r=1; do_settings=0 ;;
    --settings-only) only_s=1; do_rules=0 ;;
    --no-backup) backup=0 ;;
    --quiet) quiet=1 ;;
    -h|--help) usage; exit 0 ;;
    *) err "unknown option: $arg"; usage >&2; exit 64 ;;
  esac
done
if [ "$only_r" = 1 ] && [ "$only_s" = 1 ]; then
  err "--rules-only and --settings-only cannot be combined"; exit 64
fi

say() { [ "$quiet" = 1 ] || printf '%s\n' "$*"; }

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
target="${CLAUDE_DIR:-$HOME/.claude}"
work="$(mktemp -d)"
trap 'rm -rf "${work:?}"' EXIT

# Output files to publish: parallel arrays.
labels=() olds=() news=() dests=() existed=()

# ---- CLAUDE.md -------------------------------------------------------------
if [ "$do_rules" = 1 ]; then
  shopt -s nullglob
  rule_files=("$here"/rules/*.md)
  shopt -u nullglob
  if [ "${#rule_files[@]}" -eq 0 ]; then
    err "no rules found in $here/rules"; exit 2
  fi
  block="$work/block"
  {
    printf '%s\n' "$BEGIN"
    first=1
    for f in "${rule_files[@]}"; do
      [ "$first" = 1 ] || printf '\n'
      first=0
      printf '%s\n' "$(cat "$f")"
    done
    printf '%s\n' "$END"
  } > "$block"

  md="$target/CLAUDE.md"
  if [ -f "$md" ]; then old="$md"; ex=1; else old=/dev/null; ex=0; fi
  bl=() el=()
  while IFS= read -r l; do bl+=("${l%%:*}"); done < <(grep -nFx -- "$BEGIN" "$old" || true)
  while IFS= read -r l; do el+=("${l%%:*}"); done < <(grep -nFx -- "$END" "$old" || true)
  new="$work/CLAUDE.md"
  if [ "${#bl[@]}" -eq 0 ] && [ "${#el[@]}" -eq 0 ]; then
    {
      if [ -s "$old" ]; then
        cat "$old"
        [ -z "$(tail -c1 "$old")" ] || printf '\n'
        printf '\n'
      fi
      cat "$block"
    } > "$new"
  elif [ "${#bl[@]}" -eq 1 ] && [ "${#el[@]}" -eq 1 ] && [ "${bl[0]}" -lt "${el[0]}" ]; then
    {
      head -n $((bl[0] - 1)) "$old"
      cat "$block"
      tail -n +$((el[0] + 1)) "$old"
    } > "$new"
  else
    err "$md has malformed claude-setup markers (need exactly one begin line before one end line); nothing changed"
    exit 2
  fi
  labels+=("CLAUDE.md"); olds+=("$old"); news+=("$new"); dests+=("$md"); existed+=("$ex")
fi

# ---- settings.json ---------------------------------------------------------
if [ "$do_settings" = 1 ]; then
  patch="$here/settings.patch.json"
  if command -v jq >/dev/null 2>&1; then tool=jq
  elif command -v python3 >/dev/null 2>&1; then tool=python3
  else err "need jq or python3 to merge settings.json"; exit 3
  fi
  st="$target/settings.json"
  if [ -f "$st" ]; then old="$st"; ex=1; src="$st"
  else old=/dev/null; ex=0; src="$work/empty.json"; echo '{}' > "$src"
  fi
  new="$work/settings.json"
  merged=ok
  if [ "$tool" = jq ]; then
    jq --indent 2 -s 'if length == 2 and (.[0]|type) == "object" and (.[1]|type) == "object"
                      then .[0] * .[1] else error("not a JSON object") end' \
      "$src" "$patch" > "$new" 2>/dev/null || merged=fail
  else
    python3 -I -c '
import json, sys
def merge(a, b):
    for k, v in b.items():
        if isinstance(v, dict) and isinstance(a.get(k), dict):
            merge(a[k], v)
        else:
            a[k] = v
    return a
a = json.load(open(sys.argv[1]))
b = json.load(open(sys.argv[2]))
if not isinstance(a, dict) or not isinstance(b, dict):
    sys.exit(1)
json.dump(merge(a, b), sys.stdout, indent=2, ensure_ascii=False)
sys.stdout.write("\n")
' "$src" "$patch" > "$new" 2>/dev/null || merged=fail
  fi
  if [ "$merged" = fail ]; then
    err "$st is not a valid JSON object; nothing changed"; exit 2
  fi
  labels+=("settings.json"); olds+=("$old"); news+=("$new"); dests+=("$st"); existed+=("$ex")
fi

# ---- publish ---------------------------------------------------------------
ts="$(date -u +%Y%m%dT%H%M%SZ)"
changed=0
for i in "${!labels[@]}"; do
  label="${labels[$i]}" old="${olds[$i]}" new="${news[$i]}" dest="${dests[$i]}" ex="${existed[$i]}"
  if [ "$ex" = 1 ] && cmp -s "$old" "$new"; then
    say "$label: unchanged"; continue
  fi
  changed=1
  if [ "$ex" = 1 ]; then verb=updated; else verb=created; fi
  [ "$quiet" = 1 ] || diff -u --label "$dest" --label "$dest (new)" "$old" "$new" || true
  if [ "$dry" = 1 ]; then say "$label: would be $verb"; continue; fi
  mkdir -p "$target"
  if [ "$ex" = 1 ] && [ "$backup" = 1 ]; then cp -p "$dest" "$dest.bak.$ts"; fi
  tmp="$(mktemp "$target/.${label}.XXXXXX")"
  cat "$new" > "$tmp"
  if [ "$ex" = 1 ]; then
    chmod "$(stat -c %a "$dest" 2>/dev/null || stat -f %Lp "$dest")" "$tmp"
  else
    chmod 644 "$tmp"
  fi
  mv -f "$tmp" "$dest"
  say "$label: $verb"
done

if [ "$dry" = 1 ] && [ "$changed" = 1 ]; then exit 10; fi
exit 0
