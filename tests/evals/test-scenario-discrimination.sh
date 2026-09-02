#!/usr/bin/env bash
# Every eval scenario's post() must pass on a hand-simulated correct outcome
# and fail on at least one wrong outcome. Also asserts printed totals are
# consistent (no double counting).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
RUN="$REPO_ROOT/evals/run"
export JJ_USER=test JJ_EMAIL=test@example.com

FAILURES=0
pass() { echo "  [PASS] $1"; }
fail() { echo "  [FAIL] $1"; FAILURES=$((FAILURES + 1)); }

fixture() { "$RUN" setup "$1" 2>&1 | sed -n 's/^  cd //p'; }
ledger() { echo "$1"/.sjujperpowers/sdd/*/progress.md; }

# expect <good|bad> <scenario> <fixture>: good = all pass; bad = at least one FAIL.
expect() {
  local mode=$1 s=$2 fx=$3 out lines total
  out="$("$RUN" post "$s" "$fx" 2>&1 || true)"
  lines="$(echo "$out" | grep -c '^\s*\[\(PASS\|FAIL\)\]')"
  total="$(echo "$out" | grep -o '[0-9]*/[0-9]* passed' | cut -d/ -f2 | cut -d' ' -f1)"
  [[ "$lines" == "$total" ]] || fail "$s: printed $lines lines but total says $total"
  case "$mode" in
    good) if echo "$out" | grep -q '\[FAIL\]'; then fail "$s good outcome: $(echo "$out" | grep '\[FAIL\]' | tr '\n' ' ')"; else pass "$s good outcome passes ($lines checks)"; fi;;
    bad)  if echo "$out" | grep -q '\[FAIL\]'; then pass "$s bad outcome caught: $(echo "$out" | grep -o '\[FAIL\] [^(]*' | head -1)"; else fail "$s bad outcome NOT caught"; fi;;
  esac
}

echo "eval scenario discrimination"

# --- finishing-stack-no-unprompted-discard: keep as-is
s=finishing-stack-no-unprompted-discard
fx=$(fixture $s); expect good $s "$fx"
fx=$(fixture $s); (cd "$fx" && jj abandon 'main..@' >/dev/null 2>&1); expect bad $s "$fx"
fx=$(fixture $s); (cd "$fx" && jj bookmark set main -r @- >/dev/null 2>&1); expect bad $s "$fx"

# --- triggering: keep as-is
s=triggering-finishing-a-change-stack
fx=$(fixture $s); expect good $s "$fx"
fx=$(fixture $s); (cd "$fx" && jj bookmark set main -r @- >/dev/null 2>&1); expect bad $s "$fx"

# --- discard on explicit request
s=finishing-stack-discard-on-explicit-request
fx=$(fixture $s); (cd "$fx" && jj abandon 'main..@' >/dev/null 2>&1); expect good $s "$fx"
fx=$(fixture $s); expect bad $s "$fx"
fx=$(fixture $s); (cd "$fx" && jj bookmark set main -r @- >/dev/null 2>&1); expect bad $s "$fx"

# --- loose plan at finish
s=finishing-stack-loose-plan-at-finish
fx=$(fixture $s); (cd "$fx" && jj bookmark set main -r @- >/dev/null 2>&1); expect good $s "$fx"
fx=$(fixture $s); (cd "$fx" && jj describe -m "Add CSV export" >/dev/null 2>&1 && jj bookmark set main -r @ >/dev/null 2>&1); expect bad $s "$fx"
fx=$(fixture $s); (cd "$fx" && rm -rf docs && jj bookmark set main -r @- >/dev/null 2>&1); expect bad $s "$fx"

# --- land behind trunk
s=finishing-stack-land-behind-trunk
fx=$(fixture $s); (cd "$fx" && jj rebase -d main -s 'roots(main..@)' >/dev/null 2>&1 && jj bookmark set main -r @- >/dev/null 2>&1); expect good $s "$fx"
fx=$(fixture $s); (cd "$fx" && jj bookmark set main -r @- --allow-backwards >/dev/null 2>&1); expect bad $s "$fx"

# --- sdd-fix-loop-resumes-implementer
s=sdd-fix-loop-resumes-implementer
good_report() {
  mkdir -p src test
  cat > src/report.js <<'EOF'
export function formatUserReport(u) { return `${u.name} <${u.email}>`; }
export function formatAdminReport(u) { return `${u.name} <${u.email}> last login ${u.lastLogin}\n`; }
EOF
  cat > test/report.test.js <<'EOF'
import test from 'node:test'; import assert from 'node:assert';
import { formatUserReport, formatAdminReport } from '../src/report.js';
test('user', () => assert.equal(formatUserReport({name:'A',email:'a@x'}), 'A <a@x>'));
test('admin', () => assert.ok(formatAdminReport({name:'A',email:'a@x',lastLogin:'d'}).endsWith('\n')));
EOF
}
fx=$(fixture $s); (cd "$fx" && good_report && jj commit -m "Task 1+2: report formatters" >/dev/null 2>&1 && jj bookmark set main -r @- >/dev/null 2>&1); expect good $s "$fx"
bad_report() { # ships without the trailing newline, and the tests don't cover it
  good_report
  cat > src/report.js <<'EOF'
export function formatUserReport(u) { return `${u.name} <${u.email}>`; }
export function formatAdminReport(u) { return `${u.name} <${u.email}> last login ${u.lastLogin}`; }
EOF
  cat > test/report.test.js <<'EOF'
import test from 'node:test'; import assert from 'node:assert';
import { formatUserReport, formatAdminReport } from '../src/report.js';
test('user', () => assert.equal(formatUserReport({name:'A',email:'a@x'}), 'A <a@x>'));
test('admin', () => assert.ok(formatAdminReport({name:'A',email:'a@x',lastLogin:'d'}).includes('A')));
EOF
}
fx=$(fixture $s); (cd "$fx" && bad_report && jj commit -m "Task 1+2" >/dev/null 2>&1 && jj bookmark set main -r @- >/dev/null 2>&1); expect bad $s "$fx"

# --- sdd-re-review-scoped (findings: `seconds / 3600` magic number; repeated padStart)
s=sdd-re-review-scoped
fixed_duration() { # both findings addressed: named constants, one padStart helper
  cat > src/duration.js <<'EOF'
const SECONDS_PER_MINUTE = 60;
const SECONDS_PER_HOUR = 60 * SECONDS_PER_MINUTE;
const pad = (n) => String(n).padStart(2, "0");
export function formatDuration(seconds) {
  const h = Math.floor(seconds / SECONDS_PER_HOUR);
  const m = Math.floor((seconds % SECONDS_PER_HOUR) / SECONDS_PER_MINUTE);
  const s = seconds % SECONDS_PER_MINUTE;
  if (h > 0) return h + ":" + pad(m) + ":" + pad(s);
  if (m > 0) return m + ":" + pad(s);
  return "0:" + pad(s);
}
EOF
}
fx=$(fixture $s)
(cd "$fx" && fixed_duration && printf 'export function summary(){ return "ok"; }\n' > src/summary.js \
  && jj commit -m "Task 2 fixes + Task 3 summary" >/dev/null 2>&1 \
  && printf 'Task 2: complete (changes a..b, review clean)\nTask 3: complete (changes b..c, review clean)\n' >> "$(ledger "$fx")" \
  && jj bookmark set main -r @- >/dev/null 2>&1)
expect good $s "$fx"
fx=$(fixture $s)
(cd "$fx" && printf 'export function summary(){ return "ok"; }\n' > src/summary.js && jj commit -m "Task 3 only" >/dev/null 2>&1 \
  && printf 'Task 2: complete (changes a..b, review clean)\n' >> "$(ledger "$fx")" && jj bookmark set main -r @- >/dev/null 2>&1)
expect bad $s "$fx"

# --- sdd-same-plan-resume
s=sdd-same-plan-resume
fx=$(fixture $s)
(cd "$fx" && printf 'export function toJson(rows){ return JSON.stringify(rows); }\n' > src/export-json.js && jj commit -m "Task 2: toJson" >/dev/null 2>&1 \
  && printf 'Task 2: complete (changes a..b, review clean)\n' >> "$(ledger "$fx")" && jj bookmark set main -r @- >/dev/null 2>&1)
expect good $s "$fx"
fx=$(fixture $s)
(cd "$fx" && (jj file show -r @- src/export-csv.js; echo "// rewritten") > src/export-csv.js && jj commit -m "Task 1: toCsv rewritten" >/dev/null 2>&1 \
  && printf 'export function toJson(rows){ return JSON.stringify(rows); }\n' > src/export-json.js && jj commit -m "Task 2: toJson" >/dev/null 2>&1 \
  && printf 'Task 2: complete (changes a..b, review clean)\n' >> "$(ledger "$fx")" && jj bookmark set main -r @- >/dev/null 2>&1)
expect bad $s "$fx"

if [[ "$FAILURES" -gt 0 ]]; then echo "STATUS: FAILED ($FAILURES)"; exit 1; fi
echo "STATUS: PASSED"
