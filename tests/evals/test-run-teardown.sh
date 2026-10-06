#!/usr/bin/env bash
# evals/run teardown must remove only directories setup created: a mktemp dir
# directly under TMPDIR containing a `repo` fixture and an ownership marker.
# Anything else is refused with exit 2 and left in place.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
RUN="$REPO_ROOT/evals/run"
export JJ_USER=test JJ_EMAIL=test@example.com

# Private TMPDIR so the test never touches real /tmp entries.
TEST_ROOT=$(mktemp -d)
trap 'rm -rf "$TEST_ROOT"' EXIT
export TMPDIR="$TEST_ROOT"

FAILURES=0
pass() { echo "  [PASS] $1"; }
fail() { echo "  [FAIL] $1"; FAILURES=$((FAILURES + 1)); }

echo "evals/run teardown"

# setup fixture is removed: exit 0, marker-bearing parent gone.
fx=$("$RUN" setup finishing-stack-no-unprompted-discard 2>&1 | sed -n 's/^  cd //p')
if "$RUN" teardown "$fx" >/dev/null && [[ ! -d "$(dirname "$fx")" ]]; then
  pass "setup fixture is removed"
else
  fail "setup fixture not removed: $fx"
fi

# Hand-made $TMPDIR/tmp.X/repo with no ownership marker is refused and kept.
mkdir -p "$TEST_ROOT/tmp.X/repo"
set +e; "$RUN" teardown "$TEST_ROOT/tmp.X/repo" >/dev/null 2>&1; code=$?; set -e
if [[ "$code" -eq 2 && -d "$TEST_ROOT/tmp.X/repo" ]]; then
  pass "unmarked tmp.* dir is refused"
else
  fail "unmarked tmp.* dir: exit $code"
fi

# A nested path under a mktemp dir is refused.
mkdir -p "$TEST_ROOT/tmp.Y/sub/repo"
set +e; "$RUN" teardown "$TEST_ROOT/tmp.Y/sub/repo" >/dev/null 2>&1; code=$?; set -e
if [[ "$code" -eq 2 && -d "$TEST_ROOT/tmp.Y/sub/repo" ]]; then
  pass "nested path is refused"
else
  fail "nested path: exit $code"
fi

# A path outside TMPDIR is refused even with the marker.
outside=$(mktemp -d /tmp/tmp.teardown-test.XXXXXX)
mkdir -p "$outside/repo"; : > "$outside/.evals-run-fixture"
set +e; "$RUN" teardown "$outside/repo" >/dev/null 2>&1; code=$?; set -e
if [[ "$code" -eq 2 && -d "$outside" ]]; then
  pass "path outside TMPDIR is refused"
else
  fail "outside TMPDIR: exit $code"
fi
rm -rf "$outside"

if [[ "$FAILURES" -gt 0 ]]; then echo "STATUS: FAILED ($FAILURES)"; exit 1; fi
echo "STATUS: PASSED"
