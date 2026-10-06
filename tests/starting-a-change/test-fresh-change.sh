#!/usr/bin/env bash
# End-to-end handoff test for starting-a-change's fresh-change script:
# a spec committed by brainstorming on top of trunk must still be in the
# working copy after the implementation change is started, and loose WIP
# must never be absorbed.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
FRESH="$REPO_ROOT/skills/starting-a-change/scripts/fresh-change"
TRUNK_REV="$REPO_ROOT/skills/starting-a-change/scripts/trunk-rev"
ADD_WS="$REPO_ROOT/skills/starting-a-change/scripts/add-workspace"
REVIEW_PKG="$REPO_ROOT/skills/subagent-driven-development/scripts/review-package"

export JJ_USER=test JJ_EMAIL=test@example.com
FAILURES=0
TEST_ROOT="$(mktemp -d)"
trap 'rm -rf "$TEST_ROOT"' EXIT

pass() { echo "  [PASS] $1"; }
fail() { echo "  [FAIL] $1"; FAILURES=$((FAILURES + 1)); }
assert_eq() { if [[ "$1" == "$2" ]]; then pass "$3"; else fail "$3 (expected '$2', got '$1')"; fi; }

make_repo() {
  local dir="$TEST_ROOT/$1"
  mkdir -p "$dir"
  (cd "$dir" && jj git init >/dev/null 2>&1 && echo base > base.txt \
    && jj commit -m "base" >/dev/null 2>&1 && jj bookmark create main -r @- >/dev/null 2>&1)
  echo "$dir"
}

echo "fresh-change handoff tests"

# Case 1: brainstorming committed a spec on top of trunk; @ is empty+undescribed.
repo="$(make_repo spec-then-start)"
warn="$(cd "$repo" && "$FRESH" 2>&1 >/dev/null)"
assert_eq "$warn" "" "no warning when a local main bookmark resolves the trunk"
assert_eq "$(cd "$repo" && "$TRUNK_REV")" "main main" "trunk-rev resolves local main without config changes"
nobm="$TEST_ROOT/no-bookmark"; mkdir -p "$nobm"
(cd "$nobm" && jj git init >/dev/null 2>&1 && echo base > base.txt && jj commit -m base >/dev/null 2>&1)
set +e; (cd "$nobm" && "$TRUNK_REV" >/dev/null 2>&1); tr_code=$?; set -e
assert_eq "$tr_code" "1" "trunk-rev fails when neither remote nor local trunk exists"
warn="$(cd "$nobm" && "$FRESH" 2>&1 >/dev/null)"
[[ "$warn" == *"no trunk found"* ]] && pass "fresh-change warns when no trunk exists" || fail "missing no-trunk warning: $warn"
(cd "$repo" && mkdir -p docs/project/specs && echo spec > docs/project/specs/x-design.md \
  && jj commit -m "Add x design spec" >/dev/null 2>&1)
out="$(cd "$repo" && "$FRESH")"
assert_eq "${out#* }" "reused" "empty undescribed @ above a spec commit is reused"
[[ -f "$repo/docs/project/specs/x-design.md" ]] && pass "spec stays in the working copy" || fail "spec lost from working copy"
stack="$(cd "$repo" && jj --config 'revset-aliases."trunk()"=main' log -r 'trunk()..@ & ~empty()' --no-graph -T 'description.first_line() ++ "\n"')"
assert_eq "$stack" "Add x design spec" "stack on trunk keeps the spec commit"

# Case 2: @ is described (a deliberate change) -> new change on top, ancestry kept.
repo="$(make_repo described-wc)"
(cd "$repo" && echo plan > plan.md && jj describe -m "Add plan" >/dev/null 2>&1)
out="$(cd "$repo" && "$FRESH")"
assert_eq "${out#* }" "new-on-top" "described @ gets a new change on top"
[[ -f "$repo/plan.md" ]] && pass "described work stays in the working copy" || fail "described work lost"
parent="$(cd "$repo" && jj log -r @- --no-graph -T 'description.first_line()')"
assert_eq "$parent" "Add plan" "new change's parent is the described change"

# Case 3: loose WIP (non-empty, undescribed) -> sibling change; WIP untouched and not absorbed.
repo="$(make_repo loose-wip)"
(cd "$repo" && echo spec > spec.md && jj commit -m "Add spec" >/dev/null 2>&1 && echo scratch > wip.txt)
wip_id="$(cd "$repo" && jj log -r @ --no-graph -T 'change_id.short()')"
out="$(cd "$repo" && "$FRESH")"
read -r _ mode reported_wip <<<"$out"
assert_eq "$mode" "new-beside-wip" "loose WIP yields a sibling change"
assert_eq "$reported_wip" "$wip_id" "reports the WIP change it left aside"
[[ ! -f "$repo/wip.txt" ]] && pass "WIP file is not in the new working copy" || fail "WIP absorbed into new change"
[[ -f "$repo/spec.md" ]] && pass "committed spec below the WIP stays in the working copy" || fail "spec lost beside WIP"
wip_files="$(cd "$repo" && jj diff -r "$wip_id" --name-only)"
assert_eq "$wip_files" "wip.txt" "WIP change still holds exactly its file"

# Case 3b: the artifact protocol — WIP already in @, spec+plan committed BY FILESET
# (as brainstorming/writing-plans do), then fresh-change. WIP must stay out of both.
repo="$(make_repo fileset-protocol)"
(cd "$repo" && echo scratch > wip.txt && mkdir -p docs/project/specs docs/project/plans \
  && echo spec > docs/project/specs/y-design.md \
  && jj commit docs/project/specs/y-design.md -m "Add y design spec" >/dev/null 2>&1 \
  && echo plan > docs/project/plans/y.md \
  && jj commit docs/project/plans/y.md -m "Add y implementation plan" >/dev/null 2>&1)
spec_files="$(cd "$repo" && jj diff -r 'description(exact:"Add y design spec\n")' --name-only)"
assert_eq "$spec_files" "docs/project/specs/y-design.md" "fileset commit holds only the spec"
out="$(cd "$repo" && "$FRESH")"
read -r _ mode _ <<<"$out"
assert_eq "$mode" "new-beside-wip" "WIP survives two fileset commits and is stepped beside"
[[ -f "$repo/docs/project/plans/y.md" && -f "$repo/docs/project/specs/y-design.md" ]] \
  && pass "spec and plan are in the implementation working copy" || fail "spec/plan missing from working copy"
[[ ! -f "$repo/wip.txt" ]] && pass "WIP not absorbed by the artifact protocol" || fail "WIP leaked into implementation change"

# Case 3c: a self-review correction made AFTER the spec commit is stranded unless it is
# re-committed by fileset (brainstorming's "re-commit after any revision" rule).
spec=docs/project/specs/z-design.md
repo="$(make_repo review-correction)"
(cd "$repo" && echo scratch > wip.txt && mkdir -p docs/project/specs \
  && printf 'spec\nTBD\n' > "$spec" && jj commit "$spec" -m "Add z design spec" >/dev/null 2>&1 \
  && printf 'spec\nresolved\n' > "$spec")
stranded="$(cd "$repo" && jj new --quiet '@-' && cat "$spec")"
assert_eq "$stranded" "$(printf 'spec\nTBD')" "uncommitted correction is stranded beside the stack (the bug the ordering rule prevents)"
(cd "$repo" && jj abandon --quiet @ 2>/dev/null; jj edit --quiet "$(jj log -r 'description(exact:"")  & ~root() & ~empty()' --no-graph -T 'change_id.short()')")
corrected_wc="$(cd "$repo" && cat "$spec")"
assert_eq "$corrected_wc" "$(printf 'spec\nresolved')" "back on the WIP change holding the correction"
(cd "$repo" && jj commit "$spec" -m "Revise z design spec" >/dev/null 2>&1)
out="$(cd "$repo" && "$FRESH")"
read -r _ mode _ <<<"$out"
assert_eq "$mode" "new-beside-wip" "leftover WIP still stepped beside after re-commit"
assert_eq "$(cat "$repo/$spec")" "$(printf 'spec\nresolved')" "re-committed correction reaches the implementation change"
[[ ! -f "$repo/wip.txt" ]] && pass "WIP stays out after the revision commit" || fail "WIP leaked after revision commit"

# Case 5: optional separate workspace — the .workspaces/ ignore entry is committed by
# fileset BEFORE the workspace is created, so the workspace descends from it and
# loose WIP in the default workspace is neither absorbed nor left as a stray.
repo="$(make_repo workspace)"
(cd "$repo" && echo spec > spec.md && jj commit -m "Add spec" >/dev/null 2>&1 && echo scratch > wip.txt)
out="$(cd "$repo" && "$ADD_WS" feat)"
read -r ws_path ws_id <<<"$out"
assert_eq "$ws_path" "$(cd "$repo" && pwd -P)/.workspaces/feat" "workspace created under .workspaces/"
assert_eq "$ws_id" "$(jj -R "$ws_path" log -r @ --no-graph -T 'change_id.short()')" "prints the workspace's working-copy change id"
ignore_files="$(cd "$repo" && jj diff -r 'description(exact:"Ignore .workspaces/\n")' --name-only)"
assert_eq "$ignore_files" ".gitignore" "ignore entry committed by fileset (only .gitignore)"
ws_parent="$(jj -R "$ws_path" log -r @- --no-graph -T 'description.first_line()')"
assert_eq "$ws_parent" "Ignore .workspaces/" "workspace change descends from the committed ignore entry"
[[ -f "$ws_path/spec.md" && ! -f "$ws_path/wip.txt" ]] && pass "workspace has the stack but not the WIP" || fail "workspace contents wrong"
wip_files="$(cd "$repo" && jj diff -r @ --name-only)"
assert_eq "$wip_files" "wip.txt" "default workspace still holds exactly its WIP"
ws_tracked="$(cd "$repo" && jj file list | grep -c '^\.workspaces/' || true)"
assert_eq "$ws_tracked" "0" ".workspaces/ contents are not tracked by jj"
set +e; (cd "$repo" && "$ADD_WS" feat >/dev/null 2>&1); dup_code=$?; set -e
assert_eq "$dup_code" "2" "duplicate workspace name is refused"

# Case 6: fork topology (origin + newer upstream). jj's built-in trunk() picks by
# timestamp and flips to main@upstream; trunk-rev returns the local bookmark.
fw="$TEST_ROOT/fork"; mkdir -p "$fw/repo"
git init -q --bare "$fw/origin.git"; git init -q --bare "$fw/upstream.git"
(cd "$fw/repo" && jj git init >/dev/null 2>&1 && echo a > f && jj commit -m base >/dev/null 2>&1 \
  && jj bookmark create main -r @- >/dev/null 2>&1 \
  && jj git remote add origin "$fw/origin.git" && jj git remote add upstream "$fw/upstream.git" \
  && jj git push --remote origin -b main >/dev/null 2>&1 \
  && git -C "$fw/upstream.git" fetch -q "$fw/origin.git" main:main && jj git fetch --remote upstream >/dev/null 2>&1)
assert_eq "$(cd "$fw/repo" && "$TRUNK_REV")" "main main" "local bookmark when it equals origin"
sleep 1
(cd "$fw/repo" && echo fork > g && jj commit -m "fork change" >/dev/null 2>&1 && jj bookmark set main -r @- >/dev/null 2>&1 \
  && jj git push --remote origin -b main >/dev/null 2>&1)
sleep 1
(cd "$fw/repo" && jj new --quiet 'main@upstream' && echo up > h && jj commit -m "newer upstream change" >/dev/null 2>&1 \
  && jj bookmark create umain -r @- >/dev/null 2>&1 && jj git push --remote upstream -b umain >/dev/null 2>&1 \
  && git -C "$fw/upstream.git" update-ref refs/heads/main refs/heads/umain && jj git fetch --remote upstream >/dev/null 2>&1)
builtin="$(cd "$fw/repo" && jj log -r 'trunk()' --no-graph -T 'description.first_line()')"
assert_eq "$builtin" "newer upstream change" "built-in trunk() flips to the newer upstream commit (the hazard)"
tr_out="$(cd "$fw/repo" && "$TRUNK_REV")"
assert_eq "$tr_out" "main main" "trunk-rev ignores a newer upstream"
assert_eq "$(cd "$fw/repo" && jj log -r "${tr_out%% *}" --no-graph -T 'description.first_line()')" "fork change" "trunk-rev revset resolves to the fork's head"

# Case 7: local main is one landed change ahead of main@origin (landed, not pushed).
# The stack finishing shows, the discard target, and the classified range all start
# at local main, so the landed change is in none of them. A diverged main stops.
la="$TEST_ROOT/landed-ahead"; mkdir -p "$la/repo"; git init -q --bare "$la/origin.git"
(cd "$la/repo" && jj git init >/dev/null 2>&1 && echo a > f && jj commit -m base >/dev/null 2>&1 \
  && jj bookmark create main -r @- >/dev/null 2>&1 && jj git remote add origin "$la/origin.git" \
  && jj git push --remote origin -b main >/dev/null 2>&1 \
  && echo landed > landed.txt && jj commit -m "landed change" >/dev/null 2>&1 && jj bookmark set main -r @- >/dev/null 2>&1 \
  && echo work > work.txt && jj commit -m "stack change" >/dev/null 2>&1)
set +e; tr_out="$(cd "$la/repo" && "$TRUNK_REV" 2>&1)"; tr_code=$?; set -e
assert_eq "$tr_code/$tr_out" "0/main main" "local main ahead of origin resolves to local main"
TRUNK="${tr_out%% *}"
stack="$(cd "$la/repo" && jj log -r "$TRUNK..@ ~ empty()" --no-graph -T 'description.first_line() ++ "\n"')"
assert_eq "$stack" "stack change" "shown stack excludes the landed change"
discard="$(cd "$la/repo" && jj log -r "$TRUNK..@" --no-graph -T 'description.first_line() ++ "|"')"
[[ "$discard" != *"landed change"* ]] && pass "discard target excludes the landed change" || fail "discard target includes landed change: $discard"
cls="$(node "$REPO_ROOT/skills/verifying-by-risk/scripts/classify-risk.mjs" --repo "$la/repo")"
cls_paths="$(node -e 'const c=JSON.parse(process.argv[1]); console.log(c.paths.map(p=>p.to).join(","))' "$cls")"
assert_eq "$cls_paths" "work.txt" "classified range matches the shown stack"
git clone -q "$la/origin.git" "$la/other"
(cd "$la/other" && echo other > other.txt && git add other.txt \
  && git -c user.name=t -c user.email=t@t commit -qm "other landing" && git push -q origin HEAD:main)
(cd "$la/repo" && jj git fetch >/dev/null 2>&1)
set +e; tr_err="$(cd "$la/repo" && "$TRUNK_REV" 2>&1 >/dev/null)"; tr_code=$?; set -e
assert_eq "$tr_code" "1" "diverged main (conflicted after fetch) stops trunk-rev"
[[ "$tr_err" == *"conflicted"* ]] && pass "diverged message names the conflict" || fail "unexpected message: $tr_err"
set +e; (node "$REPO_ROOT/skills/verifying-by-risk/scripts/classify-risk.mjs" --repo "$la/repo" >/dev/null 2>&1); cls_code=$?; set -e
assert_eq "$cls_code" "2" "diverged main stops classification too"
(cd "$la/repo" && jj bookmark set main -r 'main@origin-' --allow-backwards >/dev/null 2>&1)
set +e; tr_err="$(cd "$la/repo" && "$TRUNK_REV" 2>&1 >/dev/null)"; tr_code=$?; set -e
assert_eq "$tr_code" "1" "local main behind origin stops trunk-rev"
[[ "$tr_err" == *"behind"* ]] && pass "behind message says behind" || fail "unexpected message: $tr_err"
set +e; fc_err="$(cd "$la/repo" && "$FRESH" 2>&1 >/dev/null)"; fc_code=$?; set -e
assert_eq "$fc_code" "1" "local main behind origin stops fresh-change"
[[ "$fc_err" == *"behind"* ]] && pass "fresh-change relays trunk-rev's message" || fail "unexpected message: $fc_err"

# Case 8: another workspace landed on local main after this work began.
# fresh-change starts on the current trunk when nothing of ours sits on the old
# base, and stops with a rebase command when a stack does. Reviews diff from the
# fork point, so the sibling landing never shows up as a deletion in the stack.
land_sibling() { # <repo>: another workspace lands l.txt on main beside this one's @
  local other="$1.other"
  (cd "$1" && jj workspace add --quiet --name other -r main "$other" >/dev/null 2>&1)
  (cd "$other" && echo landed > l.txt && jj commit -m "sibling landing" >/dev/null 2>&1 \
    && jj bookmark set main -r @- >/dev/null 2>&1)
  (cd "$1" && jj workspace forget other >/dev/null 2>&1)
}
repo="$(make_repo stale-empty)"
land_sibling "$repo"
out="$(cd "$repo" && "$FRESH")"
assert_eq "${out#* }" "new-on-trunk" "empty @ on an old trunk moves to the current trunk"
[[ -f "$repo/l.txt" ]] && pass "new change sees the sibling landing" || fail "new change is still on the old trunk"
repo="$(make_repo stale-wip)"
land_sibling "$repo"
(cd "$repo" && echo scratch > wip.txt)
wip_id="$(cd "$repo" && jj log -r @ --no-graph -T 'change_id.short()')"
out="$(cd "$repo" && "$FRESH")"
assert_eq "${out#* }" "new-on-trunk $wip_id" "loose WIP on an old trunk is stepped aside onto the current trunk"
[[ -f "$repo/l.txt" && ! -f "$repo/wip.txt" ]] && pass "WIP not absorbed when moving to trunk" || fail "wrong working copy after new-on-trunk"
assert_eq "$(cd "$repo" && jj diff -r "$wip_id" --name-only)" "wip.txt" "WIP change still holds exactly its file"
repo="$(make_repo stale-stack)"
(cd "$repo" && echo spec > spec.md && jj commit -m "Add spec" >/dev/null 2>&1)
land_sibling "$repo"
spec_id="$(cd "$repo" && jj log -r @- --no-graph -T 'change_id.short()')"
before="$(cd "$repo" && jj log -r @ --no-graph -T 'commit_id')"
set +e; fc_err="$(cd "$repo" && "$FRESH" 2>&1 >/dev/null)"; fc_code=$?; set -e
assert_eq "$fc_code" "1" "a stack forked from an older trunk stops fresh-change"
[[ "$fc_err" == *"jj rebase -s $spec_id -d main"* ]] && pass "stop names the rebase command" || fail "unexpected message: $fc_err"
assert_eq "$(cd "$repo" && jj log -r @ --no-graph -T 'commit_id')" "$before" "the stopped run leaves @ untouched"
fork="$(cd "$repo" && "$TRUNK_REV" --fork-point @)"
assert_eq "$fork" "$(cd "$repo" && jj log -r 'description(exact:"base\n")' --no-graph -T 'commit_id')" "fork point is where the stack left trunk"
(cd "$repo" && "$REVIEW_PKG" spec.md "$fork" @ "$TEST_ROOT/fork.diff" >/dev/null 2>&1) || : > "$TEST_ROOT/fork.diff"
files="$(sed -n '/^## Files changed/,/^## Diff/p' "$TEST_ROOT/fork.diff")"
[[ "$files" == *spec.md* && "$files" != *l.txt* ]] && pass "review from the fork point shows only the stack" || fail "fork-point review package: $files"
(cd "$repo" && "$REVIEW_PKG" spec.md "$(jj log -r main --no-graph -T 'commit_id')" @ "$TEST_ROOT/trunk.diff" >/dev/null)
[[ "$(cat "$TEST_ROOT/trunk.diff")" == *l.txt* ]] && pass "fixture: diffing from the trunk commit shows the sibling landing (the hazard)" || fail "fixture did not reproduce the hazard"

# Regression: pre-origin topology where trunk() carries an extra local label (e.g.
# `fork-base`). The bookmark must come from a main/master/trunk label, never that one.
pre="$TEST_ROOT/pre-origin"; mkdir -p "$pre/repo"; git init -q --bare "$pre/upstream.git"
(cd "$pre/repo" && jj git init >/dev/null 2>&1 && echo a > f && jj commit -m base >/dev/null 2>&1 \
  && jj bookmark create main -r @- >/dev/null 2>&1 && jj git remote add upstream "$pre/upstream.git" \
  && jj git push --remote upstream -b main >/dev/null 2>&1 && jj bookmark create fork-base -r @- >/dev/null 2>&1 \
  && jj bookmark untrack main@upstream >/dev/null 2>&1)
labels="$(cd "$pre/repo" && jj log -r 'trunk()' --no-graph -T 'bookmarks')"
[[ "$labels" == fork-base* ]] && pass "fixture: fork-base is the first label on trunk()" || fail "fixture labels unexpected: $labels"
assert_eq "$(cd "$pre/repo" && "$TRUNK_REV")" "main main" "never returns a co-located non-trunk label as the trunk bookmark"

# Case 4: not a jj repo -> exit 2 with the contract message.
plain="$TEST_ROOT/plain"; mkdir -p "$plain"
set +e
msg="$(cd "$plain" && "$FRESH" 2>&1)"; code=$?
set -e
assert_eq "$code" "2" "non-jj directory exits 2"
[[ "$msg" == *"jj git init --colocate"* ]] && pass "non-jj message offers colocate" || fail "unexpected message: $msg"

if [[ "$FAILURES" -gt 0 ]]; then
  echo "STATUS: FAILED ($FAILURES)"
  exit 1
fi
echo "STATUS: PASSED"
