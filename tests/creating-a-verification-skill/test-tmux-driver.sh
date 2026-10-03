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

# Arguments reach the program byte-for-byte whatever tmux's default-shell is:
# SHELL picks it for the private server (started with -f /dev/null). sh is
# always present; fish and zsh are checked where installed.
ARGV="driver-argv-$$"
trap '"$DRIVER" stop "$NAME" 2>/dev/null || true; "$DRIVER" stop "$FAST" 2>/dev/null || true; "$DRIVER" stop "$ARGV" 2>/dev/null || true; rm -rf "$TEST_ROOT"' EXIT
cat > "$TEST_ROOT/argv" <<'SH'
#!/usr/bin/env bash
out=$1; shift
printf '%s\0' "$@" > "$out"
SH
chmod +x "$TEST_ROOT/argv"
nasty=$'two  words\tand "dq" \'sq\' $HOME `id` \\back; (x)\nsecond line'
for shell_name in sh fish zsh; do
  shell_path=$(command -v "$shell_name" || true)
  if [[ -z "$shell_path" ]]; then
    echo "  note: $shell_name not installed; argv fidelity not checked under it"
    continue
  fi
  rm -f "$TEST_ROOT/argv.out" "$TEST_ROOT/argv.want"
  printf '%s\0%s\0' "$nasty" 'plain' > "$TEST_ROOT/argv.want"
  SHELL="$shell_path" "$DRIVER" start "$ARGV" "$TEST_ROOT" "$TEST_ROOT/argv" "$TEST_ROOT/argv.out" "$nasty" plain
  for _ in $(seq 50); do [[ -s "$TEST_ROOT/argv.out" ]] && break; sleep 0.1; done
  if cmp -s "$TEST_ROOT/argv.out" "$TEST_ROOT/argv.want"; then pass "start passes exact argv under default-shell $shell_name"; else fail "start passes exact argv under default-shell $shell_name"; fi
  "$DRIVER" stop "$ARGV"
done

# A single command word with a space is one program name, not a shell line.
mkdir -p "$TEST_ROOT/dir with space"
printf '#!/usr/bin/env bash\nprintf "%%s|%%s" "$PWD" "$#" > "$(dirname "$0")/../one.out"\n' > "$TEST_ROOT/dir with space/prog x"
chmod +x "$TEST_ROOT/dir with space/prog x"
"$DRIVER" start "$ARGV" "$TEST_ROOT/dir with space" "./prog x"
for _ in $(seq 50); do [[ -s "$TEST_ROOT/one.out" ]] && break; sleep 0.1; done
if [[ "$(cat "$TEST_ROOT/one.out" 2>/dev/null)" == "$TEST_ROOT/dir with space|0" ]]; then pass "single command word runs in the given directory without shell parsing"; else fail "single command word runs in the given directory without shell parsing"; fi
"$DRIVER" stop "$ARGV"

[[ $FAILURES -eq 0 ]] || { echo "$FAILURES failure(s)"; exit 1; }
echo "All tmux driver tests passed"
