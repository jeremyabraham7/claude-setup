#!/usr/bin/env bash
# Plain bash tests. Uses temp CLAUDE_DIRs only; never touches the real ~/.claude.
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APPLY="$ROOT/skills/claude-setup/apply.sh"
W="$(mktemp -d)"
trap 'rm -rf "${W:?}"' EXIT
pass=0 fail=0
BEGIN='<!-- claude-setup:begin -->'
END='<!-- claude-setup:end -->'

ok()   { pass=$((pass+1)); echo "PASS: $1"; }
bad()  { fail=$((fail+1)); echo "FAIL: $1"; }
check() { local d=$1; shift; if "$@" >/dev/null 2>&1; then ok "$d"; else bad "$d"; fi; }
newdir() { D="$(mktemp -d "$W/d.XXXXXX")"; }
run() { out="$(CLAUDE_DIR="$D" "$APPLY" "$@" 2>"$W/err")"; rc=$?; errout="$(cat "$W/err")"; }
baks() { ls -A "$D" | grep -c '\.bak\.' || true; }
rmbaks() { rm -f "${D:?}"/*.bak.*; }

# fresh dir
newdir; D="$D/new/.claude"; run
check "fresh: exit 0" [ $rc -eq 0 ]
check "fresh: CLAUDE.md has block" grep -qxF "$BEGIN" "$D/CLAUDE.md"
check "fresh: settings has attribution off" jq -e '.attribution.commit == "" and .includeCoAuthoredBy == false' "$D/settings.json"
check "fresh: reports created" grep -q 'CLAUDE.md: created' <<<"$out"
check "fresh: no backups" [ "$(baks)" = 0 ]

# existing CLAUDE.md with content above and below the block
newdir
printf 'top line\n\n%s\nold stale\n%s\n\nbottom line\nno newline at end' "$BEGIN" "$END" > "$D/CLAUDE.md"
cp "$D/CLAUDE.md" "$W/orig"
printf 'top line\n\n' > "$W/above"
printf '\nbottom line\nno newline at end' > "$W/below"
run
check "existing block: exit 0" [ $rc -eq 0 ]
check "existing block: content above byte-identical" bash -c 'head -c "$(wc -c < "$1")" "$2" | cmp -s "$1" -' _ "$W/above" "$D/CLAUDE.md"
check "existing block: content below byte-identical" bash -c 'tail -c "$(wc -c < "$1")" "$2" | cmp -s "$1" -' _ "$W/below" "$D/CLAUDE.md"
check "existing block: stale text gone" bash -c '! grep -q "old stale" "$1"' _ "$D/CLAUDE.md"
check "existing block: backup byte-identical to original" cmp -s "$W/orig" "$(ls "$D"/CLAUDE.md.bak.* | head -1)"
# idempotence
cp "$D/CLAUDE.md" "$W/after1"; cp "$D/settings.json" "$W/s1"; rmbaks
run
check "idempotent: exit 0" [ $rc -eq 0 ]
check "idempotent: CLAUDE.md identical" cmp -s "$W/after1" "$D/CLAUDE.md"
check "idempotent: settings identical" cmp -s "$W/s1" "$D/settings.json"
check "idempotent: no backup made" [ "$(baks)" = 0 ]
check "idempotent: reports unchanged" grep -q 'CLAUDE.md: unchanged' <<<"$out"

# append when no markers, outside content preserved
newdir; printf 'mine\nlast' > "$D/CLAUDE.md"; run --rules-only
check "append: original text preserved" bash -c 'head -n 2 "$1" | cmp -s - <(printf "mine\nlast\n")' _ "$D/CLAUDE.md"
check "append: blank line before block" bash -c '[ -z "$(sed -n 3p "$1")" ] && [ "$(sed -n 4p "$1")" = "$2" ]' _ "$D/CLAUDE.md" "$BEGIN"
check "append: rules-only leaves settings alone" [ ! -e "$D/settings.json" ]

# malformed markers
malformed() {
  local name=$1 content=$2
  newdir; printf '%b' "$content" > "$D/CLAUDE.md"; cp "$D/CLAUDE.md" "$W/m"
  run
  check "malformed ($name): exit 2" [ $rc -eq 2 ]
  check "malformed ($name): error on stderr" [ -n "$errout" ]
  check "malformed ($name): file untouched" cmp -s "$W/m" "$D/CLAUDE.md"
  check "malformed ($name): nothing else written" [ ! -e "$D/settings.json" ]
}
malformed "only begin" "x\n$BEGIN\ny\n"
malformed "only end" "x\n$END\ny\n"
malformed "duplicates" "$BEGIN\na\n$END\n$BEGIN\nb\n$END\n"
malformed "wrong order" "$END\nmid\n$BEGIN\n"

# settings
newdir; echo '{ not json' > "$D/settings.json"; cp "$D/settings.json" "$W/bad"; run
check "invalid settings: exit 2" [ $rc -eq 2 ]
check "invalid settings: file untouched" cmp -s "$W/bad" "$D/settings.json"
check "invalid settings: CLAUDE.md not written" [ ! -e "$D/CLAUDE.md" ]
newdir; : > "$D/settings.json"; run
check "empty settings file: exit 2" [ $rc -eq 2 ]

newdir; echo '{"model":"x","attribution":{"extra":1,"commit":"keep?"},"permissions":{"allow":["a"]}}' > "$D/settings.json"; run
check "settings merge: exit 0" [ $rc -eq 0 ]
check "settings merge: top-level key kept" jq -e '.model == "x" and .permissions.allow == ["a"]' "$D/settings.json"
check "settings merge: nested key kept, patch wins" jq -e '.attribution.extra == 1 and .attribution.commit == "" and .attribution.pr == "" and .includeCoAuthoredBy == false' "$D/settings.json"
check "settings merge: 2-space indent" grep -q '^  "model"' "$D/settings.json"
check "settings merge: backup made" [ "$(baks)" -ge 1 ]
newdir; echo '{"model":"y"}' > "$D/settings.json"; run --settings-only --no-backup
check "no-backup: none written" [ "$(baks)" = 0 ]

# file mode kept
newdir; printf 'hi\n' > "$D/CLAUDE.md"; chmod 640 "$D/CLAUDE.md"; run --rules-only
check "mode preserved" [ "$(stat -c %a "$D/CLAUDE.md" 2>/dev/null || stat -f %Lp "$D/CLAUDE.md")" = 640 ]

# dry-run
newdir; D="$D/none"; run --dry-run
check "dry-run fresh: exit 10" [ $rc -eq 10 ]
check "dry-run fresh: writes nothing" [ ! -e "$D" ]
check "dry-run: prints diff" grep -q '^+++ ' <<<"$out"
newdir; run; run --dry-run
check "dry-run clean: exit 0" [ $rc -eq 0 ]
echo '{"model":"z"}' > "$D/settings.json"; cp "$D/settings.json" "$W/dr"; run --dry-run
check "dry-run drift: exit 10" [ $rc -eq 10 ]
check "dry-run drift: file untouched" cmp -s "$W/dr" "$D/settings.json"
run --dry-run --quiet
check "dry-run quiet: exit 10, no output" bash -c '[ "$1" -eq 10 ] && [ -z "$2" ]' _ $rc "$out"

# quiet
newdir; run --quiet
check "quiet: exit 0 and silent" bash -c '[ "$1" -eq 0 ] && [ -z "$2" ]' _ $rc "$out"
check "quiet: files written" [ -s "$D/CLAUDE.md" ]
newdir; printf '%s\n' "$BEGIN" > "$D/CLAUDE.md"; run --quiet
check "quiet: errors still printed" bash -c '[ "$1" -eq 2 ] && [ -n "$2" ]' _ $rc "$errout"

# usage
newdir; run --bogus
check "unknown flag: exit 64" [ $rc -eq 64 ]
run --rules-only --settings-only
check "conflicting flags: exit 64" [ $rc -eq 64 ]
run --help
check "help: exit 0" [ $rc -eq 0 ]

# python3 fallback and missing deps via PATH shim
mkshim() { # name, extra tools...
  local s="$W/shim.$1"; shift; mkdir -p "$s"
  for t in bash grep head tail cat cmp diff date mktemp mv cp chmod stat rm mkdir dirname wc tr sed cut ls "$@"; do
    p="$(command -v "$t" 2>/dev/null)" && ln -sf "$p" "$s/$t"
  done
  echo "$s"
}
BASH_BIN="$(command -v bash)"
newdir; run; cp "$D/settings.json" "$W/jqout"
S="$(mkshim py python3)"
check "python fallback: no jq on shim PATH" bash -c '! PATH="$1" command -v jq' _ "$S"
newdir; echo '{"model":"x","attribution":{"extra":1}}' > "$D/settings.json"
CLAUDE_DIR="$D" PATH="$S" "$BASH_BIN" "$APPLY" --settings-only >/dev/null 2>&1; rc=$?
check "python fallback: exit 0" [ $rc -eq 0 ]
check "python fallback: merged" jq -e '.model=="x" and .attribution.extra==1 and .attribution.commit=="" and .includeCoAuthoredBy==false' "$D/settings.json"
newdir; CLAUDE_DIR="$D" PATH="$S" "$BASH_BIN" "$APPLY" --settings-only >/dev/null 2>&1
check "python fallback: fresh output matches jq output" cmp -s "$W/jqout" "$D/settings.json"
out="$(CLAUDE_DIR="$D" PATH="$S" "$BASH_BIN" "$APPLY" --settings-only 2>&1)"
check "python fallback: idempotent" grep -q 'settings.json: unchanged' <<<"$out"
echo '{bad' > "$D/settings.json"
CLAUDE_DIR="$D" PATH="$S" "$BASH_BIN" "$APPLY" --settings-only >/dev/null 2>&1; rc=$?
check "python fallback: invalid JSON exit 2" [ $rc -eq 2 ]
S2="$(mkshim none)"; newdir
CLAUDE_DIR="$D" PATH="$S2" "$BASH_BIN" "$APPLY" >/dev/null 2>"$W/err"; rc=$?
check "no jq or python3: exit 3" [ $rc -eq 3 ]
check "no jq or python3: nothing written" [ ! -e "$D/CLAUDE.md" ]

# install.sh passes args through
newdir; out="$(CLAUDE_DIR="$D" bash "$ROOT/install.sh" -- --dry-run 2>&1)"; rc=$?
check "install -- --dry-run: exit 10" [ $rc -eq 10 ]
check "install -- --dry-run: skill installed" [ -f "$D/skills/claude-setup/apply.sh" ]
check "install -- --dry-run: nothing applied" [ ! -e "$D/CLAUDE.md" ]
newdir; out="$(CLAUDE_DIR="$D" bash "$ROOT/install.sh" --no-apply 2>&1)"; rc=$?
check "install --no-apply: exit 0, not applied" bash -c '[ "$1" -eq 0 ] && [ ! -e "$2/CLAUDE.md" ] && [ -f "$2/skills/claude-setup/SKILL.md" ]' _ $rc "$D"
newdir; out="$(CLAUDE_DIR="$D" bash "$ROOT/install.sh" --symlink -- --quiet 2>&1)"; rc=$?
check "install --symlink -- --quiet: applied" bash -c '[ "$1" -eq 0 ] && [ -s "$2/CLAUDE.md" ] && [ -L "$2/skills/claude-setup" ]' _ $rc "$D"
out2="$(CLAUDE_DIR="$D" bash "$ROOT/install.sh" -- --dry-run 2>&1)"; rc=$?
check "install re-run: exit 0 (no drift)" [ $rc -eq 0 ]

echo
echo "passed: $pass  failed: $fail"
[ "$fail" -eq 0 ]
