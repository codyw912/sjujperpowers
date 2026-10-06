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
# Every fixture, and every mktemp in a scenario or script, lands under one
# directory that is removed on exit.
TEST_TMP="$(mktemp -d)"
export TMPDIR="$TEST_TMP"
trap 'rm -rf "$TEST_TMP"' EXIT
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


# --- tracking-providers-plane: provider-qualified source propagation
plane_provider_outcome() {
  local source=$1
  mkdir -p docs/project/specs docs/project/plans
  cat > docs/project/specs/2026-09-02-health-report-design.md <<'EOF'
# Health Report Design

**Outcome:** plane:DEMO-12
EOF
  cat > docs/project/plans/2026-09-02-health-report.md <<EOF
# Health Report Implementation Plan

**Spec:** \`docs/project/specs/2026-09-02-health-report-design.md\`

**Source:** $source
EOF
}
s=tracking-providers-plane
fx=$(fixture $s); (cd "$fx" && plane_provider_outcome 'plane:DEMO-12'); expect good $s "$fx"
fx=$(fixture $s); (cd "$fx" && plane_provider_outcome 'DEMO-12'); expect bad $s "$fx"

# --- tracking-providers-kata: keep-as-is preserves open execution state
kata_cmd() { PATH="$PWD/.test-bin:$PATH" kata --project sjujperpowers "$@"; }
kata_keep_good() {
  printf '%s\n' '# Demo Product' '' 'Plane owns roadmap outcomes and Kata owns activated implementation tasks' > README.md
  mkdir -p .sjujperpowers/sdd/example
  printf '%s\n' 'Task 1: complete (review clean)' > .sjujperpowers/sdd/example/progress.md
  kata_cmd --json list --status open --label sjujperpowers-task \
    --meta sjujperpowers.plan=docs/project/plans/example.md >/dev/null
  kata_cmd claim sjujperpowers#task1 --json >/dev/null
  jj describe -m "Document provider ownership

Kata: sjujperpowers#task1" >/dev/null 2>&1
  kata_cmd comment sjujperpowers#task1 --message 'Verification passed; kept open until landing.' --json >/dev/null
}
s=tracking-providers-kata
fx=$(fixture $s); (cd "$fx" && kata_keep_good); expect good $s "$fx"
fx=$(fixture $s)
(cd "$fx" && kata_keep_good && kata_cmd close sjujperpowers#task1 --json >/dev/null)
expect bad $s "$fx"

# --- tracking-providers-kata-landed: child then root close after landing
kata_land_good() {
  kata_keep_good
  jj commit -m "Document provider ownership

Kata: sjujperpowers#task1" >/dev/null 2>&1
  jj bookmark set main -r @- >/dev/null 2>&1
  kata_cmd close sjujperpowers#task1 --json >/dev/null
  kata_cmd close sjujperpowers#root --json >/dev/null
  rm -rf .sjujperpowers/sdd/example
}
s=tracking-providers-kata-landed
fx=$(fixture $s); (cd "$fx" && kata_land_good); expect good $s "$fx"
fx=$(fixture $s)
(cd "$fx" && kata_keep_good \
  && kata_cmd close sjujperpowers#root --json >/dev/null \
  && kata_cmd close sjujperpowers#task1 --json >/dev/null \
  && jj commit -m "Document provider ownership" >/dev/null 2>&1 \
  && jj bookmark set main -r @- >/dev/null 2>&1 \
  && rm -rf .sjujperpowers/sdd/example)
expect bad $s "$fx"

# --- verifying-by-risk-protected-stack
s=verifying-by-risk-protected-stack
_risk_append() {
  local grade=$1 tier=$2 protected=$3
  local root
  root=$(cd "$REPO_ROOT" && pwd)
  mkdir -p .sjujperpowers
  if [[ "$tier" != high || "$grade" != blocked ]]; then
    # Hand-written row, as an agent that classified from @'s own risk.toml would.
    local cls
    cls=$(node "$root/skills/verifying-by-risk/scripts/classify-risk.mjs")
    jq -nc --argjson c "$cls" --arg grade "$grade" --arg tier "$tier" --argjson protected "$protected" \
      '{change:$c.head.change,commit:$c.head.commit,range:$c.range,policyCommit:$c.policy.commit,tier:$tier,computedTier:$tier,protected:$protected,protectedPaths:(if $protected then ["src/auth/session.js"] else [] end),grade:$grade,runs:[],implementerFamily:"anthropic",verifierFamily:null,timestamp:"2026-10-01T00:00:00Z"}' \
      > .sjujperpowers/verdicts.jsonl
    printf '/.gitignore\n/verdicts.jsonl\n' > .sjujperpowers/.gitignore
  else
    node "$root/skills/verifying-by-risk/scripts/verdict.mjs" append \
      --grade blocked --implementer-family anthropic
  fi
}
fx=$(fixture $s); (cd "$fx" && _risk_append blocked high true); expect good $s "$fx"
fx=$(fixture $s); (cd "$fx" && _risk_append unit-tested low false); expect bad $s "$fx"
fx=$(fixture $s); (cd "$fx" && _risk_append blocked high true && jj describe -r @- -m "Document usage and retune risk (edited)" >/dev/null); expect bad $s "$fx"
fx=$(fixture $s); (cd "$fx" && _risk_append blocked high true && rm -f .sjujperpowers/.gitignore && jj commit -m "Record verdict" >/dev/null); expect bad $s "$fx"
fx=$(fixture $s); (cd "$fx" && _risk_append blocked high true \
  && jq -c '.protected = false | .protectedPaths = []' .sjujperpowers/verdicts.jsonl > "$TMPDIR/v" \
  && mv "$TMPDIR/v" .sjujperpowers/verdicts.jsonl); expect bad $s "$fx"

# --- creating-a-verification-skill-tally
s=creating-a-verification-skill-tally
_tally_skill() { # <driver: copy|modify> <symlink: yes|no> <evidence: yes|no|capture-only|repeat|final-lacks|hang>
  local driver=$1 symlink=$2 evidence=$3
  local root lib
  root=$(cd "$REPO_ROOT" && pwd)
  lib="$root/skills/creating-a-verification-skill/drivers/tmux-tty.sh"
  mkdir -p .agents/skills/verify-tally/features .agents/skills/verify-tally/scripts/lib .claude/skills
  cat > .agents/skills/verify-tally/SKILL.md <<'EOF'
# verify-tally

## Launch

Run scripts/launch. It starts bin/tally under the tmux driver as session tally.

## Doctor

Run scripts/doctor. It checks bin/tally is executable.

## Drive

Run scripts/drive-add. It adds 2 and 3 and reads the total.

## Evidence

scripts/drive-add prints the evidence directory as its last stdout line.

## Cleanup

Run scripts/cleanup. It stops session tally and is idempotent.

## Helpers

scripts/lib/tmux-tty.sh is the shipped driver. Do not reimplement it.
EOF
  printf 'Add 2 and 3, then read total=5.\n' > .agents/skills/verify-tally/features/add.md
  if [[ "$driver" == modify ]]; then
    sed 's/private tmux server/private tmux server (local copy)/' "$lib" > .agents/skills/verify-tally/scripts/lib/tmux-tty.sh
  else
    cp "$lib" .agents/skills/verify-tally/scripts/lib/tmux-tty.sh
  fi
  chmod +x .agents/skills/verify-tally/scripts/lib/tmux-tty.sh
  cat > .agents/skills/verify-tally/scripts/doctor <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
root=$(cd "$(dirname "$0")/../../../../" && pwd)
test -x "$root/bin/tally"
EOF
  cat > .agents/skills/verify-tally/scripts/launch <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
root=$(cd "$here/../../../.." && pwd)
"$here/lib/tmux-tty.sh" start tally "$root" "$root/bin/tally"
"$here/lib/tmux-tty.sh" wait tally 'tally ready' 5
EOF
  if [[ "$evidence" == repeat ]]; then
    # Two captures; the second screen still shows both adds and the total, so
    # the adds are visible twice across the evidence but must count once.
    cat > .agents/skills/verify-tally/scripts/drive-add <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
ev=$("$here/lib/tmux-tty.sh" evidence-dir tally)
"$here/lib/tmux-tty.sh" send tally 'add 2'
"$here/lib/tmux-tty.sh" send tally 'add 3'
"$here/lib/tmux-tty.sh" send tally 'total'
"$here/lib/tmux-tty.sh" wait tally 'total=5' 5
"$here/lib/tmux-tty.sh" capture tally "$ev/01-first.txt"
"$here/lib/tmux-tty.sh" send tally 'total'
sleep 0.5
"$here/lib/tmux-tty.sh" capture tally "$ev/02-final.txt"
printf '%s\n' "$ev"
EOF
  elif [[ "$evidence" == final-lacks ]]; then
    # The first capture has the right total; the app is then restarted and the
    # final capture is only the idle banner.
    cat > .agents/skills/verify-tally/scripts/drive-add <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
root=$(cd "$here/../../../.." && pwd)
ev=$("$here/lib/tmux-tty.sh" evidence-dir tally)
"$here/lib/tmux-tty.sh" send tally 'add 2'
"$here/lib/tmux-tty.sh" send tally 'add 3'
"$here/lib/tmux-tty.sh" send tally 'total'
"$here/lib/tmux-tty.sh" wait tally 'total=5' 5
"$here/lib/tmux-tty.sh" capture tally "$ev/01-first.txt"
"$here/lib/tmux-tty.sh" stop tally
"$here/lib/tmux-tty.sh" start tally "$root" "$root/bin/tally"
"$here/lib/tmux-tty.sh" wait tally 'tally ready' 5
"$here/lib/tmux-tty.sh" capture tally "$ev/02-final.txt"
printf '%s\n' "$ev"
EOF
  elif [[ "$evidence" == hang ]]; then
    # Launch succeeds, then the drive never returns (until the post-check is killed).
    cat > .agents/skills/verify-tally/scripts/drive-add <<'EOF'
#!/usr/bin/env bash
exec sleep 300
EOF
  elif [[ "$evidence" == capture-only ]]; then
    # A nonempty capture of the idle screen; the feature is never driven.
    cat > .agents/skills/verify-tally/scripts/drive-add <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
ev=$("$here/lib/tmux-tty.sh" evidence-dir tally)
"$here/lib/tmux-tty.sh" capture tally "$ev/screen.txt"
printf '%s\n' "$ev"
EOF
  elif [[ "$evidence" == yes ]]; then
    cat > .agents/skills/verify-tally/scripts/drive-add <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
ev=$("$here/lib/tmux-tty.sh" evidence-dir tally)
"$here/lib/tmux-tty.sh" send tally 'add 2'
"$here/lib/tmux-tty.sh" send tally 'add 3'
"$here/lib/tmux-tty.sh" send tally 'total'
"$here/lib/tmux-tty.sh" wait tally 'total=5' 5
"$here/lib/tmux-tty.sh" capture tally "$ev/screen.txt"
printf '%s\n' "$ev"
EOF
  else
    cat > .agents/skills/verify-tally/scripts/drive-add <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "skipped"
EOF
  fi
  cat > .agents/skills/verify-tally/scripts/cleanup <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
"$here/lib/tmux-tty.sh" stop tally
EOF
  chmod +x .agents/skills/verify-tally/scripts/doctor \
    .agents/skills/verify-tally/scripts/launch \
    .agents/skills/verify-tally/scripts/drive-add \
    .agents/skills/verify-tally/scripts/cleanup
  if [[ "$symlink" == yes ]]; then
    ln -s ../../.agents/skills/verify-tally .claude/skills/verify-tally
  fi
}
fx=$(fixture $s); (cd "$fx" && _tally_skill copy yes yes); expect good $s "$fx"
fx=$(fixture $s); (cd "$fx" && _tally_skill modify yes yes); expect bad $s "$fx"
fx=$(fixture $s); (cd "$fx" && _tally_skill copy no yes); expect bad $s "$fx"
fx=$(fixture $s); (cd "$fx" && _tally_skill copy yes no); expect bad $s "$fx"
# Captures only `tally ready`: the add and the total never happen.
fx=$(fixture $s); (cd "$fx" && _tally_skill copy yes capture-only); expect bad $s "$fx"
# Two captures. The final one still shows both adds plus the total, as the
# earlier one did: the repeated `add` lines must not be counted twice.
fx=$(fixture $s); (cd "$fx" && _tally_skill copy yes repeat); expect good $s "$fx"
# The earlier capture has the right total; the final capture is only the idle
# banner. Evidence summed across captures would wrongly pass.
fx=$(fixture $s); (cd "$fx" && _tally_skill copy yes final-lacks); expect bad $s "$fx"
# Interrupting the post-check mid-drive must still kill its private tmux server
# and remove its scratch state. The run gets its own process group (setsid, with
# INT re-enabled, since background jobs start with INT ignored) and the signal
# goes to the whole group, as a terminal's Ctrl-C would.
for sig in TERM INT; do
  fx=$(fixture $s); (cd "$fx" && _tally_skill copy yes hang)
  perl -e '$SIG{INT} = "DEFAULT"; exec @ARGV' setsid "$RUN" post $s "$fx" >/dev/null 2>&1 &
  tally_pid=$!
  for _ in $(seq 100); do tmux -L sjujp-verify-tally has-session -t tally 2>/dev/null && break; sleep 0.1; done
  sleep 0.3
  kill "-$sig" -- "-$tally_pid" 2>/dev/null || true
  wait "$tally_pid" 2>/dev/null || true
  if tmux -L sjujp-verify-tally has-session -t tally 2>/dev/null; then
    fail "$s: SIG$sig during the drive leaks the tmux server"
    tmux -L sjujp-verify-tally kill-server 2>/dev/null || true
  else
    pass "$s: SIG$sig during the drive cleans up the tmux server"
  fi
done
fx=$(fixture $s); (cd "$fx" && _tally_skill copy yes yes \
  && printf '#!/usr/bin/env bash\nexit 0\n' > .agents/skills/verify-tally/scripts/cleanup); expect bad $s "$fx"

# --- learning-from-feedback-red-green (needs hk 2.4.0 on PATH)
s=learning-from-feedback-red-green
if ! command -v hk >/dev/null 2>&1; then
  echo "  [SKIP] $s: hk not on PATH"
else
_feedback_rule() { # <glob>
  cat > hk.pkl <<EOF
amends "package://github.com/jdx/hk/releases/download/v2.4.0/hk@2.4.0#/Config.pkl"

hooks {
  ["check"] {
    steps {
      ["readme-nonempty"] {
        glob = "README.md"
        check = "sh -c 'test -s {{files}}'"
      }
      ["scaffold-intact"] {
        check = "scripts/check-scaffold"
      }
      ["no-console-log"] {
        glob = "$1"
        check = "sh -c '! grep -Hn console\\\\.log {{files}}'"
      }
    }
  }
}
EOF
}
_feedback_fix() {
  mkdir -p src
  cat > src/log.js <<'EOF'
export function log(label) {
  return label;
}
EOF
  cat > src/report.js <<'EOF'
import { log } from './log.js';
export function report(label) {
  log(label);
  return label;
}
EOF
}
fx=$(fixture $s)
(cd "$fx" && _feedback_rule 'src/**' && jj commit -m "Reject console.log in src" >/dev/null && _feedback_fix && jj commit -m "Route diagnostics through src/log.js" >/dev/null)
expect good $s "$fx"
# A rule that ships its own executable check script is also a good outcome:
# the rule change holds hk.pkl plus scripts/check-no-console, nothing else.
_feedback_script_hkpkl() {
  cat > hk.pkl <<'EOF'
amends "package://github.com/jdx/hk/releases/download/v2.4.0/hk@2.4.0#/Config.pkl"

hooks {
  ["check"] {
    steps {
      ["readme-nonempty"] {
        glob = "README.md"
        check = "sh -c 'test -s {{files}}'"
      }
      ["scaffold-intact"] {
        check = "scripts/check-scaffold"
      }
      ["no-console-in-src"] {
        check = "scripts/check-no-console"
      }
    }
  }
}
EOF
}
_feedback_script_rule() {
  _feedback_script_hkpkl
  cat > scripts/check-no-console <<'EOF'
#!/bin/sh
set -eu
! grep -rn 'console\.log' src/
EOF
  chmod 755 scripts/check-no-console
}
fx=$(fixture $s)
(cd "$fx" && _feedback_fix && jj commit -m "Route diagnostics through src/log.js" >/dev/null && _feedback_script_rule && jj commit -m "Reject console.log in src" >/dev/null)
expect good $s "$fx"
# The script left out of the rule change travels with the code fix instead: the
# rule change touches only hk.pkl, so the delivered export lacks the script and
# red's rule step fails for the wrong reason (command not found), which must be
# caught.
fx=$(fixture $s)
(cd "$fx" && cat > scripts/check-no-console <<'EOF'
#!/bin/sh
set -eu
! grep -rn 'console\.log' src/
EOF
  chmod 755 scripts/check-no-console && _feedback_fix && jj commit -m "Route diagnostics through src/log.js" >/dev/null && _feedback_script_hkpkl && jj commit -m "Reject console.log in src" >/dev/null)
expect bad $s "$fx"
# Node helper shipped with the rule and printing what it found: good.
_feedback_node_hkpkl() {
  _feedback_script_hkpkl
  sed 's|check = "scripts/check-no-console"|check = "node scripts/check-no-console.mjs"|' hk.pkl > "$TMPDIR/hk.pkl.new"
  mv "$TMPDIR/hk.pkl.new" hk.pkl
}
_feedback_node_helper() {
  cat > scripts/check-no-console.mjs <<'EOF'
import fs from 'node:fs';
let bad = 0;
for (const f of fs.readdirSync('src')) {
  fs.readFileSync(`src/${f}`, 'utf8').split('\n').forEach((line, i) => {
    if (line.includes('console.log')) { console.error(`src/${f}:${i + 1}: ${line.trim()}`); bad = 1; }
  });
}
process.exit(bad);
EOF
}
fx=$(fixture $s)
(cd "$fx" && _feedback_fix && jj commit -m "Route diagnostics through src/log.js" >/dev/null && _feedback_node_hkpkl && _feedback_node_helper && jj commit -m "Reject console.log in src" >/dev/null)
expect good $s "$fx"
# The Node helper travels with the code fix instead of the rule change: RED
# exits 1 with MODULE_NOT_FOUND and never reaches the assertion; must be caught.
fx=$(fixture $s)
(cd "$fx" && _feedback_node_helper && _feedback_fix && jj commit -m "Route diagnostics through src/log.js" >/dev/null && _feedback_node_hkpkl && jj commit -m "Reject console.log in src" >/dev/null)
expect bad $s "$fx"
# The helper ships with the rule but exits 1 without printing a finding, so
# RED shows no offending file or match: not the intended assertion.
fx=$(fixture $s)
(cd "$fx" && _feedback_fix && jj commit -m "Route diagnostics through src/log.js" >/dev/null && _feedback_node_hkpkl \
  && printf "import fs from 'node:fs';\nprocess.exit(fs.readFileSync('src/report.js', 'utf8').includes('console.log') ? 1 : 0);\n" > scripts/check-no-console.mjs \
  && jj commit -m "Reject console.log in src" >/dev/null)
expect bad $s "$fx"
# The rule left uncommitted in @ (jj snapshots @, so files(hk.pkl) alone
# matches a dirty working copy). Caught by jj-described / != @.
fx=$(fixture $s)
(cd "$fx" && _feedback_fix && jj commit -m "Route diagnostics through src/log.js" >/dev/null && _feedback_script_rule)
expect bad $s "$fx"
fx=$(fixture $s)
(cd "$fx" && _feedback_rule 'lib/**' && jj commit -m "Reject console.log in lib" >/dev/null && _feedback_fix && jj commit -m "Route diagnostics through src/log.js" >/dev/null)
expect bad $s "$fx"
fx=$(fixture $s)
(cd "$fx" && _feedback_rule 'src/**' && _feedback_fix && jj commit -m "Reject console.log and fix report" >/dev/null)
expect bad $s "$fx"
fx=$(fixture $s)
(cd "$fx" && _feedback_fix && jj commit -m "Route diagnostics through src/log.js" >/dev/null)
expect bad $s "$fx"
# The fixed head lost the helper's exec bit: the git archive export is not executable.
fx=$(fixture $s)
(cd "$fx" && _feedback_rule 'src/**' && jj commit -m "Reject console.log in src" >/dev/null && _feedback_fix && chmod -x scripts/check-scaffold && jj commit -m "Route diagnostics through src/log.js" >/dev/null)
expect bad $s "$fx"
# The fixed head replaced the symlink with a plain copy.
fx=$(fixture $s)
(cd "$fx" && _feedback_rule 'src/**' && jj commit -m "Reject console.log in src" >/dev/null && _feedback_fix && rm config/notice.txt && cp shared/notice.txt config/notice.txt && jj commit -m "Route diagnostics through src/log.js" >/dev/null)
expect bad $s "$fx"
fi

if [[ "$FAILURES" -gt 0 ]]; then echo "STATUS: FAILED ($FAILURES)"; exit 1; fi
echo "STATUS: PASSED"
