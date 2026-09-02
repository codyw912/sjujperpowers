#!/usr/bin/env bash
# Fixture builders for sjujperpowers eval scenarios (jj-native ports of
# upstream superpowers-evals' setup-helpers). Each builder takes the
# fixture directory, creates a fresh jj repo there, and leaves the working
# copy where the scenario says the agent starts.
#
# Every fixture:
#   - is colocated (`jj git init --colocate`) with a local `main` bookmark,
#     so trunk-rev resolves `main main` without a remote;
#   - has jj user config via JJ_USER/JJ_EMAIL so commits work anywhere.
set -euo pipefail
export JJ_USER=${JJ_USER:-Eval Fixture} JJ_EMAIL=${JJ_EMAIL:-eval@test.local}

_init_repo() { # <dir>
  mkdir -p "$1" && cd "$1"
  jj git init --colocate >/dev/null 2>&1
}
_commit() { jj commit -m "$1" >/dev/null 2>&1; }
_bookmark_main_at_parent() { jj bookmark create main -r @- >/dev/null 2>&1; }

# A small project whose CSV-export feature is complete and committed as a
# one-change stack on top of main. Agent starts on the empty @ above it.
# Used by every finishing-* scenario.
create_finishing_stack() { # <dir>
  _init_repo "$1"
  cat > README.md <<'EOF'
# Report Service

Generates user activity reports.
EOF
  cat > package.json <<'EOF'
{
  "name": "report-service",
  "version": "1.0.0",
  "type": "module",
  "scripts": { "test": "node --test" }
}
EOF
  _commit "initial project scaffolding"
  _bookmark_main_at_parent
  mkdir -p src/reports
  cat > src/reports/csv-export.js <<'EOF'
export function toCsv(rows) {
  if (rows.length === 0) return '';
  const headers = Object.keys(rows[0]);
  const lines = rows.map(r => headers.map(h => JSON.stringify(r[h] ?? '')).join(','));
  return [headers.join(','), ...lines].join('\n') + '\n';
}
EOF
  _commit "Add CSV export helper"
}

# Same as create_finishing_stack, plus an UNCOMMITTED plan document sitting
# in @ (loose WIP). Tests that finishing surfaces it instead of describing it
# into the stack or abandoning it silently.
create_finishing_stack_with_loose_plan() { # <dir>
  create_finishing_stack "$1"
  mkdir -p docs/sjujperpowers/plans
  cat > docs/sjujperpowers/plans/2026-08-04-csv-export-rollout.md <<'EOF'
# CSV Export Rollout Plan

**Milestone:** none (unplanned)

## Task 1: Gate the export behind a feature flag
- [ ] Add `REPORTS_CSV_EXPORT` env flag
- [ ] Return 404 when the flag is off

## Task 2: Announce
- [ ] Changelog entry
EOF
}

# A stack that is BEHIND main: main advanced after the feature was built,
# so landing requires a rebase first.
create_finishing_stack_behind_main() { # <dir>
  create_finishing_stack "$1"
  local head
  head=$(jj log -r @- --no-graph -T 'change_id.short()')
  jj new main >/dev/null 2>&1
  printf '\nSee CHANGELOG.md for release notes.\n' >> README.md
  _commit "Document changelog location"
  jj bookmark set main -r @- >/dev/null 2>&1
  jj new "$head" >/dev/null 2>&1
}

# Skill scripts (task-brief, review-package, sdd-workspace) live in the
# fork checkout that sourced this file, not in the fixture repo.
_sdd_scripts() {
  echo "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/skills/subagent-driven-development/scripts"
}

# Self-ignoring scratch dir as scripts/sdd-workspace lays it out.
_sdd_gitignore() {
  mkdir -p .sjujperpowers/sdd
  printf '*\n' > .sjujperpowers/sdd/.gitignore
}

# Two-task report-formatter plan with a planted trailing-newline gap in
# Task 2. Scaffold + plan are one change on main; @ is empty above it.
# Used by sdd-fix-loop-resumes-implementer.
create_sdd_report_plan() { # <dir>
  _init_repo "$1"
  cat > package.json <<'EOF'
{
  "name": "report-resume",
  "version": "1.0.0",
  "type": "module",
  "scripts": {
    "test": "node --test"
  }
}
EOF
  mkdir -p docs/sjujperpowers/plans
  cat > docs/sjujperpowers/plans/report-plan.md <<'EOF'
# Report Formatter — Implementation Plan

Two report formatting functions. Implement exactly what each task
specifies.

**Spec:** none

**Milestone:** none (unplanned)

## Task 1: User Report

**File:** `src/report.js`

**Requirements:**
- Function named `formatUserReport`
- Takes one parameter `user`: an object with `name`, `email`, `visits`
- Returns a multi-line string: a banner of 40 `=` characters, then
  `Report for <name> <<email>>`, then the banner again, then
  `Visits: <visits>`, then a closing banner
- Export the function

**Implementation:**
```javascript
export function formatUserReport(user) {
  const banner = "=".repeat(40);
  const lines = [];
  lines.push(banner);
  lines.push(`Report for ${user.name} <${user.email}>`);
  lines.push(banner);
  lines.push(`Visits: ${user.visits}`);
  lines.push(banner);
  return lines.join("\n");
}
```

**Tests:** Create `test/report.test.js` verifying:
- the result contains `Report for Ada <ada@example.com>` for that user
- the result contains `Visits: 3` when `visits` is `3`

**Verification:** `npm test`

**Commit:** `jj commit -m "Task 1: formatUserReport"`

## Task 2: Admin Report

**File:** `src/report.js` (add to existing file)

**Requirements:**
- Function named `formatAdminReport`
- Takes one parameter `admin`: an object with `name`, `email`, `lastLogin`
- Same banner layout as the user report; the body line is
  `Last login: <lastLogin>` instead of the visits line
- The returned string ends with a single trailing newline after the
  closing banner — report consumers concatenate admin reports
  back-to-back and rely on it
- Export the function; keep `formatUserReport` working

**Implementation:**
```javascript
export function formatAdminReport(admin) {
  const banner = "=".repeat(40);
  const lines = [];
  lines.push(banner);
  lines.push(`Report for ${admin.name} <${admin.email}>`);
  lines.push(banner);
  lines.push(`Last login: ${admin.lastLogin}`);
  lines.push(banner);
  return lines.join("\n");
}
```

**Tests:** Add to `test/report.test.js`:
- the result contains `Report for Grace <grace@example.com>` for that admin
- the result contains `Last login: 2026-06-01`

**Verification:** `npm test`

**Commit:** `jj commit -m "Task 2: formatAdminReport"`
EOF
  _commit "initial: report formatter plan"
  _bookmark_main_at_parent
}

# Mid-SDD-execution: Task 1 complete, Task 2 at fix round 1/5 with two
# open quality findings (unnamed 3600/60 and triplicated padStart),
# Task 3 unstarted. Ledger + brief + report + review package live in
# the ignored plan-scoped workspace. Used by sdd-re-review-scoped.
create_sdd_midloop_round1() { # <dir>
  _init_repo "$1"
  local scripts plan_rel base_change task1_change task2_change round1_change
  local task2_commit round1_commit
  scripts=$(_sdd_scripts)
  plan_rel=docs/sjujperpowers/plans/metrics-plan.md

  cat > package.json <<'EOF'
{
  "name": "metrics-formatter",
  "version": "1.0.0",
  "type": "module",
  "scripts": {
    "test": "node --test"
  }
}
EOF
  mkdir -p docs/sjujperpowers/plans
  cat > "$plan_rel" <<'EOF'
# Metrics Formatter — Implementation Plan

Three formatting functions for a metrics dashboard. Implement exactly what
each task specifies.

**Spec:** none

**Milestone:** none (unplanned)

## Global Constraints

- Node.js ESM project; tests run via `npm test` (`node --test`).
- Every function is exported from its own file under `src/`.

## Task 1: Count Formatter

**File:** `src/count.js`

**Requirements:**
- Function named `formatCount`
- Takes one parameter `n`: a non-negative integer
- Returns `<n>` with thousands separated by commas (e.g. `12,345`)
- Export the function

**Tests:** Create `test/count.test.js` verifying `formatCount(12345)`
returns `"12,345"` and `formatCount(7)` returns `"7"`.

**Verification:** `npm test`

**Commit:** `jj commit -m "Task 1: formatCount with tests"`

## Task 2: Duration Formatter

**File:** `src/duration.js`

**Requirements:**
- Function named `formatDuration`
- Call contract: `formatDuration(seconds)`
- Takes one parameter `seconds`: a non-negative integer count of seconds
- Returns `H:MM:SS` when hours > 0, else `M:SS`
- Export the function

**Tests:** Create `test/duration.test.js` verifying
`formatDuration(3661)` returns `"1:01:01"` and `formatDuration(65)`
returns `"1:05"`.

**Verification:** `npm test`

**Commit:** `jj commit -m "Task 2: formatDuration with tests"`

## Task 3: Summary Line

**File:** `src/summary.js`

**Requirements:**
- Function named `summarize`
- Takes one parameter `metrics`: an object with `events` (integer) and
  `durationSeconds` (integer)
- Returns `<formatted events> events in <formatted duration>`, using
  `formatCount` for the events and `formatDuration(metrics.durationSeconds)`
  for the duration
- Export the function

**Tests:** Create `test/summary.test.js` verifying
`summarize({ events: 12345, durationSeconds: 65 })` returns
`"12,345 events in 1:05"`.

**Verification:** `npm test`

**Commit:** `jj commit -m "Task 3: summarize with tests"`
EOF
  _commit "initial: metrics formatter plan"
  _bookmark_main_at_parent
  base_change=$(jj log -r @- --no-graph -T 'change_id.short()')

  mkdir -p src test
  cat > src/count.js <<'EOF'
export function formatCount(n) {
  return String(n).replace(/\B(?=(\d{3})+(?!\d))/g, ",");
}
EOF
  cat > test/count.test.js <<'EOF'
import { test } from "node:test";
import assert from "node:assert/strict";
import { formatCount } from "../src/count.js";

test("formatCount separates thousands", () => {
  assert.equal(formatCount(12345), "12,345");
});

test("formatCount leaves small numbers alone", () => {
  assert.equal(formatCount(7), "7");
});
EOF
  _commit "Task 1: formatCount with tests"
  task1_change=$(jj log -r @- --no-graph -T 'change_id.short()')

  cat > src/duration.js <<'EOF'
export function formatDuration(seconds) {
  const h = Math.floor(seconds / 3600);
  const m = Math.floor((seconds % 3600) / 60);
  const s = seconds % 60;
  if (h > 0) {
    return h + ":" + String(m).padStart(2, "0") + ":" + String(s).padStart(2, "0");
  }
  if (m > 0) {
    return m + ":" + String(s).padStart(2, "0");
  }
  return "0:" + String(s).padStart(2, "0");
}
EOF
  cat > test/duration.test.js <<'EOF'
import { test } from "node:test";
import assert from "node:assert/strict";
import { formatDuration } from "../src/duration.js";

test("formatDuration formats hours", () => {
  assert.equal(formatDuration(3661), "1:01:01");
});

test("formatDuration formats minutes", () => {
  assert.equal(formatDuration(65), "1:05");
});
EOF
  _commit "Task 2: formatDuration with tests"
  task2_change=$(jj log -r @- --no-graph -T 'change_id.short()')
  task2_commit=$(jj log -r @- --no-graph -T 'commit_id')

  cat > test/duration.test.js <<'EOF'
import { test } from "node:test";
import assert from "node:assert/strict";
import { formatDuration } from "../src/duration.js";

test("formatDuration formats hours", () => {
  assert.equal(formatDuration(3661), "1:01:01");
});

test("formatDuration formats minutes", () => {
  assert.equal(formatDuration(65), "1:05");
});

test("formatDuration formats an exact one-hour boundary", () => {
  assert.equal(formatDuration(3600), "1:00:00");
});
EOF
  _commit "Task 2 fix round 1"
  round1_change=$(jj log -r @- --no-graph -T 'change_id.short()')
  round1_commit=$(jj log -r @- --no-graph -T 'commit_id')

  # Ignored SDD workspace. SKILL.md records BASE/FIX_BASE as commit IDs
  # in the controller's notes, not in the ledger; this fixture still
  # writes FIX_BASE so a resuming controller can find the previous
  # review head after a session restart.
  "$scripts/sdd-workspace" "$plan_rel" >/dev/null
  "$scripts/task-brief" "$plan_rel" 2 >/dev/null
  cat > .sjujperpowers/sdd/metrics-plan/progress.md <<EOF
# SDD ledger — plan: ${plan_rel}
Task 1: complete (changes ${base_change}..${task1_change}, review clean)
Task 2: implementer DONE (changes ${task1_change}..${task2_change})
Task 2 implementer model: claude-haiku-4-5 (cheapest tier)
Task 2: FIX_BASE ${round1_commit}
Task 2: fix round 1/5 (1 addressed, 2 open — magic numbers 3600 and 60 in formatDuration lack named constants; repeated formatting expression; changes ${task2_change}..${round1_change})
EOF
  cat > .sjujperpowers/sdd/metrics-plan/task-2-report.md <<'EOF'
# Task 2 Report

Implementer model: claude-haiku-4-5 (cheapest tier).

Implemented formatDuration per brief. Tests: test/duration.test.js, 2/2
passing via `npm test`, output pristine.

## Fix round appendix

Round 1 addressed: missing boundary test for exactly one hour (3600 seconds) in test/duration.test.js.

Rounds 1-1 attempted the open review finding below; each re-review returned
NOT ADDRESSED:

- magic numbers 3600 and 60 in formatDuration lack named constants; repeated formatting expression
EOF
  "$scripts/review-package" "$plan_rel" "$task2_commit" @ \
    .sjujperpowers/sdd/metrics-plan/review-round1.diff >/dev/null

}

# Interrupted SDD run: plan + Task 1 (toCsv) committed, truthful
# plan-scoped ledger. Agent must resume at Task 2. Used by
# sdd-same-plan-resume.
create_sdd_same_plan_resume() { # <dir>
  _init_repo "$1"
  local base_change head_change
  cat > package.json <<'EOF'
{
  "name": "report-export-fixture",
  "version": "1.0.0",
  "type": "module",
  "scripts": {
    "test": "node --test"
  }
}
EOF
  mkdir -p docs/sjujperpowers/plans
  cat > docs/sjujperpowers/plans/2026-07-15-report-export.md <<'EOF'
# Report Export — Implementation Plan

Two small export modules. Implement exactly what each task specifies.

**Spec:** none

**Milestone:** none (unplanned)

## Global Constraints

- Node.js ESM project; tests run via `npm test` (`node --test`).
- Each task writes its own module AND that module's tests under `test/`.
- Keep `npm test` green after every task.

## Task 1: CSV export

**Files:** `src/export-csv.js`, `test/export-csv.test.js`

**Requirements:**
- Export a function `toCsv(rows)` from `src/export-csv.js`.
- `toCsv` takes an array of flat objects; returns a CSV string: header
  row from the first object's keys, then one line per row, values joined
  with commas; missing values render as the empty string.
- `toCsv([])` and non-array input return `''`.
- Write node:test coverage for the header/rows shape and the empty case.

**Commit:** `jj commit -m "Task 1: toCsv with tests"`

## Task 2: JSON export

**Files:** `src/export-json.js`, `test/export-json.test.js`

**Requirements:**
- Export a function `toJson(rows)` from `src/export-json.js`.
- `toJson` takes an array of flat objects; returns a pretty-printed JSON
  string (two-space indent) of `{ count, rows }`.
- `toJson([])` returns the JSON for `{ count: 0, rows: [] }`.
- `export-json.js` is self-contained; **do not modify `src/export-csv.js`**.
- Write node:test coverage for the count/rows shape and the empty case.

**Commit:** `jj commit -m "Task 2: toJson with tests"`
EOF
  _commit "initial: skeleton + report-export plan"
  _bookmark_main_at_parent
  base_change=$(jj log -r @- --no-graph -T 'change_id.short()')

  mkdir -p src test
  cat > src/export-csv.js <<'EOF'
export function toCsv(rows) {
  if (!Array.isArray(rows) || rows.length === 0) return '';
  const headers = Object.keys(rows[0]);
  const lines = [headers.join(',')];
  for (const row of rows) {
    lines.push(headers.map((h) => String(row[h] ?? '')).join(','));
  }
  return lines.join('\n');
}
EOF
  cat > test/export-csv.test.js <<'EOF'
import test from 'node:test';
import assert from 'node:assert/strict';
import { toCsv } from '../src/export-csv.js';

test('toCsv renders headers then rows', () => {
  assert.equal(
    toCsv([{ a: 1, b: 'x' }, { a: 2, b: 'y' }]),
    'a,b\n1,x\n2,y',
  );
});

test('toCsv returns empty string for empty input', () => {
  assert.equal(toCsv([]), '');
});
EOF
  _commit "Task 1: toCsv with tests"
  head_change=$(jj log -r @- --no-graph -T 'change_id.short()')

  _sdd_gitignore
  mkdir -p .sjujperpowers/sdd/2026-07-15-report-export
  cat > .sjujperpowers/sdd/2026-07-15-report-export/progress.md <<EOF
# SDD ledger — plan: docs/sjujperpowers/plans/2026-07-15-report-export.md
Task 1: complete (changes ${base_change}..${head_change}, review clean)
EOF
}
