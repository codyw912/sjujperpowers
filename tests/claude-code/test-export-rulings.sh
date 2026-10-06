#!/usr/bin/env bash
# Tests for scripts/export-rulings: a plan's rulings are written next to the
# plan, committed with the stack, and still readable on the trunk bookmark
# after finishing lands locally and deletes the recovery workspace.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SDD_SCRIPTS="$REPO_ROOT/skills/subagent-driven-development/scripts"

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

jj_user() {
    jj --config 'user.name="t"' --config 'user.email="t@example.com"' "$@"
}

main() {
    echo "=== Test: export-rulings ==="

    TEST_ROOT="$(mktemp -d)"
    trap cleanup EXIT

    # Defaults: session execution, no Kata, no .sjujperpowers/config.json.
    jj git init "$TEST_ROOT/repo" >/dev/null
    local repo
    repo="$(cd "$TEST_ROOT/repo" && jj root)"

    local plan_rel="docs/project/plans/2026-01-01-x.md"
    mkdir -p "$repo/docs/project/plans"
    printf '# Plan X\n\n## Task 1: Thing\n\nDo it.\n' > "$repo/$plan_rel"
    ( cd "$repo" \
        && jj_user commit -m "Add plan" >/dev/null 2>&1 \
        && jj_user bookmark create main -r @- >/dev/null 2>&1 )

    local ws
    ws="$(cd "$repo" && "$SDD_SCRIPTS/sdd-workspace" "$plan_rel")"
    cat > "$ws/progress.md" <<'LEDGER'
Plan: docs/project/plans/2026-01-01-x.md
Task 1: complete (review clean)
Ruling: use the plan's flag name — the spec is silent — rename costs one commit
Task 2: over fix-round budget 3 — missing retry on timeout
Task 2: parked — retry is contestable — Ruling: the code stands — costs a follow-up
LEDGER

    # --- export, commit by name, brief, land, clean up (finishing's order) ---
    local printed
    printed="$(cd "$repo" && "$SDD_SCRIPTS/export-rulings" "$plan_rel")"
    if [[ "$printed" == "docs/project/plans/2026-01-01-x-rulings.md" && -f "$repo/$printed" ]]; then
        pass "prints the written path relative to the repo root, next to the plan"
    else
        fail "prints the written path relative to the repo root, next to the plan"
        echo "    got: $printed"
    fi

    ( cd "$repo" && jj_user commit "$printed" -m "Record rulings for 2026-01-01-x" >/dev/null 2>&1 )

    # The brief is a message, not a tracked file. Stand it in at the repo root,
    # so a link written as the printed repo-relative path is valid from its
    # own directory.
    local brief="$repo/brief.md"
    printf '## Attention\n- Rulings: [rulings](%s), 2\n' "$printed" > "$brief"

    ( cd "$repo" && jj_user bookmark set main -r @- >/dev/null 2>&1 )
    rm -rf "$ws"

    if [[ ! -e "$ws" ]]; then
        pass "recovery workspace is gone after cleanup"
    else
        fail "recovery workspace is gone after cleanup"
    fi

    local shown
    if shown="$(cd "$repo" && jj file show -r main "$printed" 2>/dev/null)"; then
        pass "rulings file exists on main after the workspace is deleted"
    else
        fail "rulings file exists on main after the workspace is deleted"
        shown=""
    fi

    local first=$'Ruling: use the plan\'s flag name'
    local second=$'Ruling: the code stands'
    local before_second="${shown%%"$second"*}"
    if [[ "$shown" == *"$first"* && "$shown" == *"$second"* && "$before_second" == *"$first"* ]]; then
        pass "both rulings are present, in ledger order"
    else
        fail "both rulings are present, in ledger order"
        printf '%s\n' "$shown"
    fi

    if [[ "$shown" == *"over fix-round budget 3 — missing retry on timeout"* ]]; then
        pass "the over-budget line is present"
    else
        fail "the over-budget line is present"
    fi

    if [[ "$shown" != *"Task 1: complete"* && "$shown" != *"Plan:"* ]]; then
        pass "non-ruling ledger lines are left out"
    else
        fail "non-ruling ledger lines are left out"
    fi

    local target resolved
    target="$(sed -n 's/.*](\([^)]*\)).*/\1/p' "$brief")"
    resolved="$(realpath -m "$(dirname "$brief")/$target")"
    ( cd "$repo" && jj_user new main >/dev/null 2>&1 )
    if [[ -f "$resolved" && "$resolved" == "$repo/$printed" ]] \
        && grep -q "Ruling: the code stands" "$resolved"; then
        pass "the brief's link, resolved from the brief's directory, exists on main's checkout with the rulings"
    else
        fail "the brief's link, resolved from the brief's directory, exists on main's checkout with the rulings"
        echo "    target: $target resolved: $resolved"
    fi

    # --- idempotence ---
    ws="$(cd "$repo" && "$SDD_SCRIPTS/sdd-workspace" "$plan_rel")"
    cat > "$ws/progress.md" <<'LEDGER'
Plan: docs/project/plans/2026-01-01-x.md
Ruling: first — why — cost
LEDGER
    local out1 out2 sum1 sum2
    out1="$(cd "$repo" && "$SDD_SCRIPTS/export-rulings" "$plan_rel")"
    sum1="$(cksum < "$repo/$out1")"
    out2="$(cd "$repo" && "$SDD_SCRIPTS/export-rulings" "$plan_rel")"
    sum2="$(cksum < "$repo/$out2")"
    if [[ "$out1" == "$out2" && "$sum1" == "$sum2" && "$(grep -c 'Ruling:' "$repo/$out1")" -eq 1 ]]; then
        pass "re-running overwrites the file with identical content"
    else
        fail "re-running overwrites the file with identical content"
    fi

    # --- no rulings writes None. ---
    printf 'Plan: docs/project/plans/2026-01-01-x.md\nTask 1: complete\n' > "$ws/progress.md"
    ( cd "$repo" && "$SDD_SCRIPTS/export-rulings" "$plan_rel" >/dev/null )
    local none_count
    none_count="$(grep -cx 'None\.' "$repo/$out1")"
    if [[ "$none_count" -eq 2 && "$(grep -c '^- ' "$repo/$out1")" -eq 0 ]]; then
        pass "a ledger without rulings writes None. for both sections"
    else
        fail "a ledger without rulings writes None. for both sections"
        cat "$repo/$out1"
    fi

    # --- missing ledger exits 2 ---
    rm -rf "$ws"
    local rc=0
    ( cd "$repo" && "$SDD_SCRIPTS/export-rulings" "$plan_rel" >/dev/null 2>&1 ) || rc=$?
    if [[ "$rc" -eq 2 ]]; then
        pass "a missing ledger exits 2"
    else
        fail "a missing ledger exits 2"
        echo "    exit: $rc"
    fi

    rc=0
    ( cd "$repo" && "$SDD_SCRIPTS/export-rulings" no-such-plan.md >/dev/null 2>&1 ) || rc=$?
    if [[ "$rc" -eq 2 ]]; then
        pass "a missing plan exits 2"
    else
        fail "a missing plan exits 2"
        echo "    exit: $rc"
    fi

    # --- outside a jj repo exits 2 ---
    mkdir -p "$TEST_ROOT/plain"
    printf '# P\n' > "$TEST_ROOT/plain/p.md"
    rc=0
    (cd "$TEST_ROOT/plain" && "$SDD_SCRIPTS/export-rulings" p.md >/dev/null 2>&1) || rc=$?
    if [[ "$rc" -eq 2 ]]; then
        pass "outside a jj repo exits 2"
    else
        fail "outside a jj repo exits 2"
        echo "    exit: $rc"
    fi

    echo ""
    if [[ "$FAILURES" -ne 0 ]]; then
        echo "FAILED: $FAILURES assertion(s)."
        exit 1
    fi
    echo "PASS"
}

main "$@"
