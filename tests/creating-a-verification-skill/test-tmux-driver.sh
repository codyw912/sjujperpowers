#!/usr/bin/env bash
# tmux TTY driver: start/send/wait/capture/stop against a real interactive CLI.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DRIVER="${DRIVER:-$SCRIPT_DIR/../../skills/creating-a-verification-skill/drivers/tmux-tty.sh}"
command -v tmux >/dev/null || { echo "SKIP: tmux not installed"; exit 0; }

TEST_ROOT=$(mktemp -d)
NAME="driver-test-$$"
FAST="driver-fast-$$"
export XDG_STATE_HOME="$TEST_ROOT/state"
trap '"$DRIVER" stop "$NAME" 2>/dev/null || true; "$DRIVER" stop "$FAST" 2>/dev/null || true; rm -rf "$TEST_ROOT"' EXIT

FAILURES=0
pass() { echo "  [PASS] $1"; }
fail() { echo "  [FAIL] $1"; FAILURES=$((FAILURES + 1)); }

cat > "$TEST_ROOT/tally" <<'SH'
#!/usr/bin/env bash
total=0
printf 'tally ready\n'
while IFS= read -r -p '> ' line; do
  case "$line" in
    add\ *) total=$((total + ${line#add })); printf 'ok\n' ;;
    total) printf 'total=%s\n' "$total" ;;
    quit) exit 0 ;;
    *) printf 'unknown: %s\n' "$line" ;;
  esac
done
SH
chmod +x "$TEST_ROOT/tally"

"$DRIVER" start "$NAME" "$TEST_ROOT" ./tally
if "$DRIVER" wait "$NAME" 'tally ready' 5; then pass "wait sees startup banner"; else fail "wait sees startup banner"; fi

"$DRIVER" send "$NAME" 'add 2'
"$DRIVER" send "$NAME" 'add 40'
"$DRIVER" send "$NAME" 'total'
if "$DRIVER" wait "$NAME" 'total=42' 5; then pass "send types lines the CLI reads"; else fail "send types lines the CLI reads"; fi

evidence=$("$DRIVER" evidence-dir tally)
case "$evidence" in
  "$XDG_STATE_HOME"/sjujperpowers/evidence/tally/*) pass "evidence-dir is under XDG_STATE_HOME" ;;
  *) fail "evidence-dir is under XDG_STATE_HOME (got $evidence)" ;;
esac
"$DRIVER" capture "$NAME" "$evidence/screen.txt"
if grep -q 'total=42' "$evidence/screen.txt"; then pass "capture writes the visible screen"; else fail "capture writes the visible screen"; fi

if "$DRIVER" wait "$NAME" 'never-printed' 1 2>"$TEST_ROOT/timeout.err"; then
  fail "wait times out on a missing pattern"
elif grep -q 'total=42' "$TEST_ROOT/timeout.err"; then
  pass "wait times out and prints the screen"
else
  fail "wait timeout prints the screen"
fi

if "$DRIVER" start "$NAME" "$TEST_ROOT" ./tally 2>/dev/null; then fail "second start with the same name is rejected"; else pass "second start with the same name is rejected"; fi

"$DRIVER" stop "$NAME"
if tmux -L "sjujp-verify-$NAME" has-session -t "$NAME" 2>/dev/null; then fail "stop kills the session"; else pass "stop kills the session"; fi
"$DRIVER" stop "$NAME" && pass "stop is idempotent" || fail "stop is idempotent"

"$DRIVER" start "$FAST" "$TEST_ROOT" printf 'gone-marker\n'
if "$DRIVER" wait "$FAST" 'gone-marker' 3 && "$DRIVER" capture "$FAST" "$evidence/fast.txt" && grep -q 'gone-marker' "$evidence/fast.txt"; then
  pass "capture survives a command that exits immediately"
else
  fail "capture survives a command that exits immediately"
fi
"$DRIVER" stop "$FAST"

[[ $FAILURES -eq 0 ]] || { echo "$FAILURES failure(s)"; exit 1; }
echo "All tmux driver tests passed"
