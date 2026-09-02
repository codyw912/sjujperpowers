#!/usr/bin/env bash
# scripts/fork-rename.mjs: upstream name -> fork name in contents and paths,
# attribution URLs preserved, idempotent, and never rewrites itself.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
RENAME="$REPO_ROOT/scripts/fork-rename.mjs"
UP="$(printf 'super%s' 'powers')"   # assembled so this test never carries the literal either

FAILURES=0
TEST_ROOT="$(mktemp -d)"
trap 'rm -rf "$TEST_ROOT"' EXIT
pass() { echo "  [PASS] $1"; }
fail() { echo "  [FAIL] $1"; FAILURES=$((FAILURES + 1)); }
assert_eq() { if [[ "$1" == "$2" ]]; then pass "$3"; else fail "$3 (expected '$2', got '$1')"; fi; }

echo "fork-rename tests"

fixture="$TEST_ROOT/fixture"
mkdir -p "$fixture/skills/using-$UP" "$fixture/.pi/extensions" "$fixture/scripts"
cp "$RENAME" "$fixture/scripts/fork-rename.mjs"
printf 'Use %s: see https://github.com/obra/%s/issues/571 %s %s\n' "$UP" "$UP" "${UP^}" "${UP^^}" > "$fixture/skills/using-$UP/SKILL.md"
printf 'export default function %sPiExtension() {}\n' "$UP" > "$fixture/.pi/extensions/$UP.ts"
printf 'unrelated\n' > "$fixture/README.md"
mkdir -p "$fixture/docs/${UP^^}-notes" && printf 'x\n' > "$fixture/docs/${UP^^}-notes/${UP^}.md"
before_script="$(md5sum "$fixture/scripts/fork-rename.mjs")"

out1="$(cd "$fixture" && node scripts/fork-rename.mjs)"
assert_eq "$out1" "fork-rename: rewrote 2 files, moved 4 paths" "first run rewrites both fixture files and moves all four paths"

[[ -f "$fixture/skills/using-sjujperpowers/SKILL.md" ]] && pass "skill directory renamed" || fail "skill directory not renamed"
[[ -f "$fixture/.pi/extensions/sjujperpowers.ts" ]] && pass "extension file renamed" || fail "extension file not renamed"
[[ -f "$fixture/docs/SJUJPERPOWERS-notes/Sjujperpowers.md" ]] && pass "title-case file inside upper-case directory renamed" || fail "capitalised paths not renamed"
assert_eq "$(cat "$fixture/skills/using-sjujperpowers/SKILL.md")" \
  "Use sjujperpowers: see https://github.com/obra/$UP/issues/571 Sjujperpowers SJUJPERPOWERS" \
  "all three capitalisations rewritten, attribution URL preserved"
assert_eq "$(cat "$fixture/.pi/extensions/sjujperpowers.ts")" "export default function sjujperpowersPiExtension() {}" "content inside renamed file rewritten"
assert_eq "$(cat "$fixture/README.md")" "unrelated" "untouched file left alone"
assert_eq "$(md5sum "$fixture/scripts/fork-rename.mjs")" "$before_script" "script does not rewrite itself"

out2="$(cd "$fixture" && node scripts/fork-rename.mjs)"
assert_eq "$out2" "fork-rename: rewrote 0 files, moved 0 paths" "second run is a no-op (idempotent)"

# Guard against the literal creeping back in — on a copy, so the test never mutates the repo.
copy="$TEST_ROOT/repo-copy"; mkdir -p "$copy"
(cd "$REPO_ROOT" && tar --exclude=.jj --exclude=.git --exclude=node_modules --exclude=.workspaces -cf - .) | (cd "$copy" && tar -xf -)
repo_out="$(cd "$copy" && node scripts/fork-rename.mjs)"
assert_eq "$repo_out" "fork-rename: rewrote 0 files, moved 0 paths" "repo tree is already fully renamed"

if [[ "$FAILURES" -gt 0 ]]; then echo "STATUS: FAILED ($FAILURES)"; exit 1; fi
echo "STATUS: PASSED"
