#!/usr/bin/env bash
# The rebase step documented in docs/upstream-sync.md: the preflight revset
# lists exactly what `jj rebase -s 'roots(fork-base..main)'` will move —
# including side branches forked from the middle of the stack — and moving
# them keeps their parent relationship and diff.
set -euo pipefail

export JJ_USER=test JJ_EMAIL=test@example.com
FAILURES=0
TEST_ROOT="$(mktemp -d)"
trap 'rm -rf "$TEST_ROOT"' EXIT
pass() { echo "  [PASS] $1"; }
fail() { echo "  [FAIL] $1"; FAILURES=$((FAILURES + 1)); }
assert_eq() { if [[ "$1" == "$2" ]]; then pass "$3"; else fail "$3 (expected '$2', got '$1')"; fi; }

PREFLIGHT='(roots(fork-base..main):: ~ (fork-base..main)) ~ (empty() & description(exact:""))'

echo "upstream-sync procedure tests"

repo="$TEST_ROOT/repo"; mkdir -p "$repo"; cd "$repo"
jj git init >/dev/null 2>&1
echo base > base.txt && jj commit -m "upstream v1" >/dev/null 2>&1
jj bookmark create fork-base -r @- >/dev/null 2>&1
# Fork stack: three changes on top of fork-base.
echo one > one.txt && jj commit -m "stack 1" >/dev/null 2>&1
echo two > two.txt && jj commit -m "stack 2" >/dev/null 2>&1
MID=$(jj log -r @- --no-graph -T 'change_id.short()')
echo three > three.txt && jj commit -m "stack 3" >/dev/null 2>&1
jj bookmark create main -r @- >/dev/null 2>&1
# Side branch off the middle change; WIP on main; an empty undescribed @.
jj new --quiet "$MID" && echo side > side.txt && jj describe --quiet -m "side branch off stack 2"
SIDE=$(jj log -r @ --no-graph -T 'change_id.short()')
jj new --quiet main && echo wip > wip.txt && jj describe --quiet -m "WIP on main"
WIP=$(jj log -r @ --no-graph -T 'change_id.short()')
jj new --quiet
# Upstream moves on, diverging from fork-base.
jj new --quiet fork-base && echo v2 > upstream.txt && jj commit -m "upstream v2" >/dev/null 2>&1
jj bookmark create upstream-main -r @- >/dev/null 2>&1
jj new --quiet main

pre="$(jj log -r "$PREFLIGHT" --no-graph -T 'description.first_line() ++ "\n"' | LC_ALL=C sort | tr '\n' ';')"
assert_eq "$pre" "WIP on main;side branch off stack 2;" "preflight lists the side branch and the WIP, not the empty @"

OLD_BASE=$(jj log -r fork-base --no-graph -T 'commit_id')
jj rebase -s 'roots(fork-base..main)' -d upstream-main >/dev/null 2>&1
jj bookmark set fork-base -r upstream-main >/dev/null 2>&1

stack="$(jj log -r 'fork-base..main' --no-graph -T 'description.first_line() ++ "\n"' | tr '\n' ';')"
assert_eq "$stack" "stack 3;stack 2;stack 1;" "stack is exactly the three changes on the new base"
assert_eq "$(jj log -r 'fork-base' --no-graph -T 'description.first_line()')" "upstream v2" "fork-base moved to the new upstream commit"
assert_eq "$(jj log -r "$SIDE-" --no-graph -T 'description.first_line()')" "stack 2" "side branch still parented on the middle change"
assert_eq "$(jj log -r "$SIDE & fork-base::" --no-graph -T '"yes"')" "yes" "side branch now descends from the new base"
assert_eq "$(jj diff -r "$SIDE" --name-only)" "side.txt" "side branch diff intact"
assert_eq "$(jj log -r "$WIP-" --no-graph -T 'description.first_line()')" "stack 3" "WIP still on top of main"
assert_eq "$(jj log -r 'fork-base..main & conflicts()' --no-graph -T '"x"')" "" "no conflicts in this non-overlapping case"
assert_eq "$(jj diff --from "$OLD_BASE" --to fork-base --summary)" "A upstream.txt" "audit diff covers the full upstream delta"
[[ -f "$repo/upstream.txt" && -f "$repo/three.txt" ]] && pass "working copy has upstream and stack content" || fail "working copy missing content"

if [[ "$FAILURES" -gt 0 ]]; then echo "STATUS: FAILED ($FAILURES)"; exit 1; fi
echo "STATUS: PASSED"
