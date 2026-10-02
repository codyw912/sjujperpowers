#!/usr/bin/env bash
# Fixture checks for test-no-process-substitution.sh's fence tracking. Each
# case builds a fake skills/x/SKILL.md tree in a temp dir and runs the checker
# against it: exit 1 means flagged, exit 0 means clean.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CHECK="$SCRIPT_DIR/test-no-process-substitution.sh"

FAILURES=0
TEST_ROOT=""

pass() { echo "  [PASS] $1"; }
fail() {
    echo "  [FAIL] $1"
    FAILURES=$((FAILURES + 1))
}

cleanup() {
    if [[ -n "$TEST_ROOT" && -d "$TEST_ROOT" ]]; then
        rm -rf "$TEST_ROOT"
    fi
}

# expect <flagged|clean> <description> <markdown>
expect() {
    local want="$1" desc="$2" body="$3" root rc=0
    root="$(mktemp -d "$TEST_ROOT/case.XXXXXX")"
    mkdir -p "$root/skills/x"
    printf '%s\n' "$body" > "$root/skills/x/SKILL.md"
    "$CHECK" "$root" >/dev/null 2>&1 || rc=$?
    if [[ "$want" == flagged && "$rc" -eq 1 ]] || [[ "$want" == clean && "$rc" -eq 0 ]]; then
        pass "$desc"
    else
        fail "$desc (exit $rc)"
    fi
}

main() {
    echo "=== Test: process-substitution fence tracking ==="
    TEST_ROOT="$(mktemp -d)"
    trap cleanup EXIT

    expect flagged 'inner ``` inside a four-backtick block is still inside the fence' \
'````markdown
```bash
while read -r l; do :; done < <(printf x)
```
````'

    expect clean 'prose after a closed nested block is not scanned' \
'````markdown
```bash
echo ok
```
````

Never write `< <(cmd)` in prose.'

    expect flagged 'a ~~~ line inside a ``` block does not close it' \
'```bash
~~~
cat < <(echo x)
```'

    expect flagged 'a shorter backtick run does not close a longer fence' \
'````
```
cat < <(echo x)
````'

    expect flagged 'a fence line with trailing text does not close the block' \
'```bash
echo ok
``` not-a-close
cat < <(echo x)
```'

    expect clean 'text after the real close is prose' \
'```bash
echo ok
```
cat < <(echo x)'

    expect flagged 'plain fenced block is flagged' \
'```bash
cat < <(echo x)
```'

    expect clean 'tilde fence closes on a tilde fence' \
'~~~
echo ok
~~~

cat < <(echo x)'

    local rc=0
    "$CHECK" >/dev/null 2>&1 || rc=$?
    if [[ "$rc" -eq 0 ]]; then
        pass "the real repo passes"
    else
        fail "the real repo passes (exit $rc)"
    fi

    echo ""
    if [[ "$FAILURES" -ne 0 ]]; then
        echo "FAILED: $FAILURES assertion(s)."
        exit 1
    fi
    echo "PASS"
}

main "$@"
