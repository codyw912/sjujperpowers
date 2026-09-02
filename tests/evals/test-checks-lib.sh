#!/usr/bin/env bash
# evals/lib/checks.sh: every verb records exactly one result; `not` inverts
# without double-counting; run-checks totals match the printed lines.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
export JJ_USER=test JJ_EMAIL=test@example.com

FAILURES=0
pass() { echo "  [PASS] $1"; }
fail() { echo "  [FAIL] $1"; FAILURES=$((FAILURES + 1)); }
assert_eq() { if [[ "$1" == "$2" ]]; then pass "$3"; else fail "$3 (expected '$2', got '$1')"; fi; }

echo "evals check library tests"

work="$(mktemp -d)"; trap 'rm -rf "$work"' EXIT
cd "$work" && jj git init --colocate >/dev/null 2>&1 && echo a > present.txt && jj commit -m base >/dev/null 2>&1 && jj bookmark create main -r @- >/dev/null 2>&1

# shellcheck disable=SC1091
. "$REPO_ROOT/evals/lib/checks.sh"

file-exists present.txt >/dev/null
assert_eq "$EVAL_CHECKS/$EVAL_FAILURES" "1/0" "plain verb pass: one check, no failure"

file-exists missing.txt >/dev/null
assert_eq "$EVAL_CHECKS/$EVAL_FAILURES" "2/1" "plain verb fail: one check, one failure"

not file-exists missing.txt >/dev/null
assert_eq "$EVAL_CHECKS/$EVAL_FAILURES" "3/1" "not(failing verb): exactly one more check, passes"

not file-exists present.txt >/dev/null
assert_eq "$EVAL_CHECKS/$EVAL_FAILURES" "4/2" "not(passing verb): exactly one more check, fails"

not not file-exists present.txt >/dev/null
assert_eq "$EVAL_CHECKS/$EVAL_FAILURES" "5/2" "nested not: still one check"

jj-count changes eq 0 >/dev/null
assert_eq "$EVAL_CHECKS/$EVAL_FAILURES" "6/2" "jj-count records one check"

# run-checks totals must equal the number of printed result lines.
scenario="$work/scenario"; mkdir -p "$scenario"
cat > "$scenario/checks.sh" <<'EOF'
pre() { :; }
post() {
    file-exists present.txt
    not file-exists missing.txt
    not file-exists present.txt
    jj-repo
}
EOF
EVAL_CHECKS=0; EVAL_FAILURES=0
out="$(run-checks post "$scenario" || true)"
lines="$(echo "$out" | grep -c '^\s*\[\(PASS\|FAIL\)\]')"
total="$(echo "$out" | grep -o '[0-9]*/[0-9]* passed')"
assert_eq "$lines" "4" "run-checks prints one line per verb"
assert_eq "$total" "3/4 passed" "run-checks total matches printed lines"

if [[ "$FAILURES" -gt 0 ]]; then echo "STATUS: FAILED ($FAILURES)"; exit 1; fi
echo "STATUS: PASSED"
