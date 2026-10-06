# Verification and Feedback Loop Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use sjujperpowers:subagent-driven-development (recommended) or sjujperpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the local trunk bookmark the one stack boundary, then add the three general Sjujperpowers skills from the pilot spec (`verifying-by-risk`, `creating-a-verification-skill`, `learning-from-feedback`), the hk conventions reference, and their integration into SDD, executing-plans, and finishing.

**Architecture:** starting-a-change's `trunk-rev` returns the local trunk bookmark and stops when it disagrees with `<name>@origin`; finishing and classification both use it. `verifying-by-risk` owns dependency-free Node scripts: `classify.mjs` computes the whole-stack range and loads policy and the test command from trunk, `classify-risk.mjs` prints that classification, and `verdict.mjs` keeps the untracked verdict ledger, reclassifying on every `append` and `check`. The skill text adds the tier evidence table and the operator brief. `creating-a-verification-skill` ships a reusable tmux TTY driver that generated `verify-<project>` scripts copy unchanged. `learning-from-feedback` is skill text only. Existing skills call into `verifying-by-risk` at their hand-off points.

**Tech Stack:** Node.js 22 ES modules with `node:test`; Bash, tmux 3.x, jq; Jujutsu 0.41; hk 2.4.0 (eval scenario only).

**Spec:** `docs/project/specs/2026-09-30-verification-feedback-pilot-design.md`

**Source:** plane:SJUP-2

## Global Constraints

- Sjujperpowers is public: skills, scripts, tests, and fixtures carry no private-project names, paths, transcript text, or details. Fixtures are synthetic.
- Trunk is the local trunk bookmark returned by `skills/starting-a-change/scripts/trunk-rev` (`main main`), for finishing and classification alike. Local ahead of `<name>@origin` is fine; behind, diverged, or conflicted exits 1 (classification exits 2).
- The diff range is always `fork_point(trunk | head)..head`. A supplied range is a cross-check only; any other range exits 2.
- Policy (`.sjujperpowers/risk.toml`: rules, default, `test`, protected paths) is read from the commit trunk points to at classification time, never from the change under test.
- No `risk.toml` on trunk, or a malformed one → every change is `high`.
- The unit-test command is `risk.toml`'s `test` on trunk. A grade of `unit-tested` or above needs a passing run of exactly that command; without one the grade stops at `type-check-only`.
- Built-in protected paths: `hk.pkl`, `.config/hk.pkl`, `.hk/**`, `nix/hk.nix`, `scripts/update-hk`, `.sjujperpowers/risk.toml`, `.agents/skills/verify-*/SKILL.md`, `.agents/skills/verify-*/features/**`, `.agents/skills/verify-*/scripts/**`, `.claude/skills/verify-*`, `.github/workflows/**`, `devenv.nix`, `devenv.yaml`, `devenv.lock`.
- Verdicts go to `.sjujperpowers/verdicts.jsonl`, kept untracked by a self-ignoring `.sjujperpowers/.gitignore`. `append` and `check` reclassify; neither reads a classification file. A verdict is void when its commit, fork point, or policy commit no longer matches, when its tier is below the recomputed tier, or when `protected`/`protectedPaths` differ. Protected-path approval at finishing comes from a fresh classification, never the ledger. Grade, runs, and model families are self-reported, and the brief says so.
- hk runs only through `skills/verifying-by-risk/scripts/hk-check`, never bare `hk check`: the committed root `hk.pkl` only, `HK_*` cleared, no user config, `~/.gitconfig`, or system git config, and a stop naming the source when the effective configuration still skips steps, skips hooks, or excludes files.
- A `high` verdict graded above `blocked` requires a verifier from a different model family than the implementer (only when the project has a verify skill; spec D14).
- Every test and eval check removes the temp directories it creates. Every manual RED/GREEN run ends with `evals/run teardown <fixture-dir>`, after post and also when the run fails or is abandoned.
- Operator brief: at most 40 lines, not counting links; sections Why, Scope, Tradeoffs (optional), Blast radius, Verification, Attention.
- Scripts are dependency-free (Node built-ins only). Shell files pass `shellcheck --severity=warning --external-sources --source-path=SCRIPTDIR`.
- Skill edits follow sjujperpowers:writing-skills: watch the baseline fail before writing the skill, then confirm the agent complies.
- Behavioral runs use OMP 18.4.4. The installed plugin is the pinned release, so "with the skill available" (GREEN) means the fixture loads this checkout's skills: write `.omp/config.yml` containing `skills: { customDirectories: [<this checkout>/skills] }` and add `.omp/` to the fixture's `.git/info/exclude` so Jujutsu never snapshots it. RED runs use the same config plus `omp --skills='!<skill-name>'`.
- Out of scope: self-merge, publication-policy changes, plugin release or pin bumps, GitHub Actions, a shared hk base, the changed-files adapter, verification-skill maintenance mode, a browser driver, pushes.

## File Structure

| Path | Responsibility |
|---|---|
| `skills/starting-a-change/scripts/trunk-rev` | The local trunk bookmark; stops when it is behind, diverged from, or conflicted with origin |
| `skills/verifying-by-risk/scripts/jj.mjs` | Jujutsu access: head, trunk via `trunk-rev`, fork point, changed paths, snapshot |
| `skills/verifying-by-risk/scripts/policy.mjs` | `risk.toml` parser, glob matcher, built-in protected paths, path classification |
| `skills/verifying-by-risk/scripts/classify.mjs` | Whole-stack classification shared by both CLIs |
| `skills/verifying-by-risk/scripts/classify-risk.mjs` | CLI: classification JSON for the pending stack |
| `skills/verifying-by-risk/scripts/verdict.mjs` | CLI: `append`, `check`, `summary` over the verdict ledger |
| `skills/verifying-by-risk/scripts/hk-check` | `hk check --all` pinned to the committed `hk.pkl`, with plan evidence |
| `skills/verifying-by-risk/SKILL.md` | Classify → evidence by tier → verdict → brief |
| `skills/verifying-by-risk/hk-conventions.md` | hk layout, profiles, entry points, protected paths, `risk.toml` reference |
| `skills/creating-a-verification-skill/drivers/tmux-tty.sh` | Reusable TTY driver copied into generated skills |
| `skills/creating-a-verification-skill/SKILL.md` | Generated layout, process, end-to-end proof |
| `skills/learning-from-feedback/SKILL.md` | Correction → classified rule → one batch → red/green change |
| `skills/{subagent-driven-development,executing-plans,finishing-a-change-stack}/SKILL.md` | Call into verifying-by-risk; finishing checks the verdict, shows the brief, gates protected paths |
| `tests/starting-a-change/test-fresh-change.sh` | Trunk boundary with local `main` ahead of, behind, and diverged from origin |
| `tests/verifying-by-risk/*.mjs` | Unit tests for the parser, classification, and ledger |
| `tests/verifying-by-risk/test-hk-check.sh` | hk overrides ignored or refused, against real hk |
| `tests/creating-a-verification-skill/test-tmux-driver.sh` | Driver against a real interactive CLI |
| `evals/scenarios/<three new>/` + `evals/lib/fixtures.sh` + `tests/evals/test-scenario-discrimination.sh` | One deterministic scenario per skill, proven to discriminate |

---

### Task 1: Local trunk boundary

**Files:**
- Modify: `skills/starting-a-change/scripts/trunk-rev`, `skills/starting-a-change/scripts/fresh-change`, `skills/starting-a-change/SKILL.md` (Step 2)
- Modify: `skills/finishing-a-change-stack/SKILL.md` (Step 3)
- Modify: `skills/subagent-driven-development/SKILL.md` (Final Review MERGE_BASE), `skills/requesting-code-review/SKILL.md` (BASE fallback)
- Modify: `evals/run` (`teardown`), `evals/README.md` (Running one)
- Modify: `CLAUDE.md`, `docs/upstream-sync.md`, `docs/testing.md` (trunk-rev description)
- Test: `tests/starting-a-change/test-fresh-change.sh`

**Interfaces:**
- Produces: `trunk-rev` (no arguments, cwd in the repo) prints `<name> <name>` for the first local bookmark among `main`, `master`, `trunk`. Exit 1, with a message, when there is none, when the local bookmark is conflicted (it diverged from a tracked remote and a fetch ran), or when `<name>@origin` exists and is not the local bookmark or one of its ancestors (local behind or diverged). Local ahead of origin succeeds. Every skill that writes `trunk()` uses this revset.
- Produces: `trunk-rev --fork-point REV` prints the commit ID of `fork_point(<trunk> | REV)`, with the same exit-1 stops. Review bases with no recorded commit use it.
- Produces: `fresh-change` bases new work on that bookmark. It exits 1 with trunk-rev's message when trunk-rev exits 1 (other than "no trunk", which stays a warning). When the base it would use (`@-`, or `@` for a described change) is an ancestor of trunk, it runs `jj new <trunk>` and prints `<id> new-on-trunk [<wip-id>]`. When a stack forked from an older trunk sits under `@`, it exits 1 naming `jj rebase -s <root> -d <trunk>` and changes nothing.
- Produces: `evals/run teardown <dir>` removes a fixture made by `evals/run setup` (`<TMPDIR>/tmp.*/repo`) and refuses anything else with exit 2.

- [ ] **Step 1: Write the failing test**

Apply this change to `tests/starting-a-change/test-fresh-change.sh`:

```diff
--- a/tests/starting-a-change/test-fresh-change.sh
+++ b/tests/starting-a-change/test-fresh-change.sh
@@ -10,6 +10,7 @@
 FRESH="$REPO_ROOT/skills/starting-a-change/scripts/fresh-change"
 TRUNK_REV="$REPO_ROOT/skills/starting-a-change/scripts/trunk-rev"
 ADD_WS="$REPO_ROOT/skills/starting-a-change/scripts/add-workspace"
+REVIEW_PKG="$REPO_ROOT/skills/subagent-driven-development/scripts/review-package"
 
 export JJ_USER=test JJ_EMAIL=test@example.com
 FAILURES=0
@@ -129,7 +130,7 @@
 assert_eq "$dup_code" "2" "duplicate workspace name is refused"
 
 # Case 6: fork topology (origin + newer upstream). jj's built-in trunk() picks by
-# timestamp and flips to main@upstream; trunk-rev must keep main@origin.
+# timestamp and flips to main@upstream; trunk-rev returns the local bookmark.
 fw="$TEST_ROOT/fork"; mkdir -p "$fw/repo"
 git init -q --bare "$fw/origin.git"; git init -q --bare "$fw/upstream.git"
 (cd "$fw/repo" && jj git init >/dev/null 2>&1 && echo a > f && jj commit -m base >/dev/null 2>&1 \
@@ -137,7 +138,7 @@
   && jj git remote add origin "$fw/origin.git" && jj git remote add upstream "$fw/upstream.git" \
   && jj git push --remote origin -b main >/dev/null 2>&1 \
   && git -C "$fw/upstream.git" fetch -q "$fw/origin.git" main:main && jj git fetch --remote upstream >/dev/null 2>&1)
-assert_eq "$(cd "$fw/repo" && "$TRUNK_REV")" "main@origin main" "origin bookmark preferred when remotes agree"
+assert_eq "$(cd "$fw/repo" && "$TRUNK_REV")" "main main" "local bookmark when it equals origin"
 sleep 1
 (cd "$fw/repo" && echo fork > g && jj commit -m "fork change" >/dev/null 2>&1 && jj bookmark set main -r @- >/dev/null 2>&1 \
   && jj git push --remote origin -b main >/dev/null 2>&1)
@@ -148,9 +149,81 @@
 builtin="$(cd "$fw/repo" && jj log -r 'trunk()' --no-graph -T 'description.first_line()')"
 assert_eq "$builtin" "newer upstream change" "built-in trunk() flips to the newer upstream commit (the hazard)"
 tr_out="$(cd "$fw/repo" && "$TRUNK_REV")"
-assert_eq "$tr_out" "main@origin main" "trunk-rev stays on origin when upstream is newer"
+assert_eq "$tr_out" "main main" "trunk-rev ignores a newer upstream"
 assert_eq "$(cd "$fw/repo" && jj log -r "${tr_out%% *}" --no-graph -T 'description.first_line()')" "fork change" "trunk-rev revset resolves to the fork's head"
 
+# Case 7: local main is one landed change ahead of main@origin (landed, not pushed).
+# The stack finishing shows and the discard target start at local main, so the
+# landed change is in neither. A diverged or behind main stops.
+la="$TEST_ROOT/landed-ahead"; mkdir -p "$la/repo"; git init -q --bare "$la/origin.git"
+(cd "$la/repo" && jj git init >/dev/null 2>&1 && echo a > f && jj commit -m base >/dev/null 2>&1 \
+  && jj bookmark create main -r @- >/dev/null 2>&1 && jj git remote add origin "$la/origin.git" \
+  && jj git push --remote origin -b main >/dev/null 2>&1 \
+  && echo landed > landed.txt && jj commit -m "landed change" >/dev/null 2>&1 && jj bookmark set main -r @- >/dev/null 2>&1 \
+  && echo work > work.txt && jj commit -m "stack change" >/dev/null 2>&1)
+set +e; tr_out="$(cd "$la/repo" && "$TRUNK_REV" 2>&1)"; tr_code=$?; set -e
+assert_eq "$tr_code/$tr_out" "0/main main" "local main ahead of origin resolves to local main"
+TRUNK="${tr_out%% *}"
+stack="$(cd "$la/repo" && jj log -r "$TRUNK..@ ~ empty()" --no-graph -T 'description.first_line() ++ "\n"')"
+assert_eq "$stack" "stack change" "shown stack excludes the landed change"
+discard="$(cd "$la/repo" && jj log -r "$TRUNK..@" --no-graph -T 'description.first_line() ++ "|"')"
+[[ "$discard" != *"landed change"* ]] && pass "discard target excludes the landed change" || fail "discard target includes landed change: $discard"
+git clone -q "$la/origin.git" "$la/other"
+(cd "$la/other" && echo other > other.txt && git add other.txt \
+  && git -c user.name=t -c user.email=t@t commit -qm "other landing" && git push -q origin HEAD:main)
+(cd "$la/repo" && jj git fetch >/dev/null 2>&1)
+set +e; tr_err="$(cd "$la/repo" && "$TRUNK_REV" 2>&1 >/dev/null)"; tr_code=$?; set -e
+assert_eq "$tr_code" "1" "diverged main (conflicted after fetch) stops trunk-rev"
+[[ "$tr_err" == *"conflicted"* ]] && pass "diverged message names the conflict" || fail "unexpected message: $tr_err"
+(cd "$la/repo" && jj bookmark set main -r 'main@origin-' --allow-backwards >/dev/null 2>&1)
+set +e; tr_err="$(cd "$la/repo" && "$TRUNK_REV" 2>&1 >/dev/null)"; tr_code=$?; set -e
+assert_eq "$tr_code" "1" "local main behind origin stops trunk-rev"
+[[ "$tr_err" == *"behind"* ]] && pass "behind message says behind" || fail "unexpected message: $tr_err"
+set +e; fc_err="$(cd "$la/repo" && "$FRESH" 2>&1 >/dev/null)"; fc_code=$?; set -e
+assert_eq "$fc_code" "1" "local main behind origin stops fresh-change"
+[[ "$fc_err" == *"behind"* ]] && pass "fresh-change relays trunk-rev's message" || fail "unexpected message: $fc_err"
+
+# Case 8: another workspace landed on local main after this work began.
+# fresh-change starts on the current trunk when nothing of ours sits on the old
+# base, and stops with a rebase command when a stack does. Reviews diff from the
+# fork point, so the sibling landing never shows up as a deletion in the stack.
+land_sibling() { # <repo>: another workspace lands l.txt on main beside this one's @
+  local other="$1.other"
+  (cd "$1" && jj workspace add --quiet --name other -r main "$other" >/dev/null 2>&1)
+  (cd "$other" && echo landed > l.txt && jj commit -m "sibling landing" >/dev/null 2>&1 \
+    && jj bookmark set main -r @- >/dev/null 2>&1)
+  (cd "$1" && jj workspace forget other >/dev/null 2>&1)
+}
+repo="$(make_repo stale-empty)"
+land_sibling "$repo"
+out="$(cd "$repo" && "$FRESH")"
+assert_eq "${out#* }" "new-on-trunk" "empty @ on an old trunk moves to the current trunk"
+[[ -f "$repo/l.txt" ]] && pass "new change sees the sibling landing" || fail "new change is still on the old trunk"
+repo="$(make_repo stale-wip)"
+land_sibling "$repo"
+(cd "$repo" && echo scratch > wip.txt)
+wip_id="$(cd "$repo" && jj log -r @ --no-graph -T 'change_id.short()')"
+out="$(cd "$repo" && "$FRESH")"
+assert_eq "${out#* }" "new-on-trunk $wip_id" "loose WIP on an old trunk is stepped aside onto the current trunk"
+[[ -f "$repo/l.txt" && ! -f "$repo/wip.txt" ]] && pass "WIP not absorbed when moving to trunk" || fail "wrong working copy after new-on-trunk"
+assert_eq "$(cd "$repo" && jj diff -r "$wip_id" --name-only)" "wip.txt" "WIP change still holds exactly its file"
+repo="$(make_repo stale-stack)"
+(cd "$repo" && echo spec > spec.md && jj commit -m "Add spec" >/dev/null 2>&1)
+land_sibling "$repo"
+spec_id="$(cd "$repo" && jj log -r @- --no-graph -T 'change_id.short()')"
+before="$(cd "$repo" && jj log -r @ --no-graph -T 'commit_id')"
+set +e; fc_err="$(cd "$repo" && "$FRESH" 2>&1 >/dev/null)"; fc_code=$?; set -e
+assert_eq "$fc_code" "1" "a stack forked from an older trunk stops fresh-change"
+[[ "$fc_err" == *"jj rebase -s $spec_id -d main"* ]] && pass "stop names the rebase command" || fail "unexpected message: $fc_err"
+assert_eq "$(cd "$repo" && jj log -r @ --no-graph -T 'commit_id')" "$before" "the stopped run leaves @ untouched"
+fork="$(cd "$repo" && "$TRUNK_REV" --fork-point @)"
+assert_eq "$fork" "$(cd "$repo" && jj log -r 'description(exact:"base\n")' --no-graph -T 'commit_id')" "fork point is where the stack left trunk"
+(cd "$repo" && "$REVIEW_PKG" spec.md "$fork" @ "$TEST_ROOT/fork.diff" >/dev/null 2>&1) || : > "$TEST_ROOT/fork.diff"
+files="$(sed -n '/^## Files changed/,/^## Diff/p' "$TEST_ROOT/fork.diff")"
+[[ "$files" == *spec.md* && "$files" != *l.txt* ]] && pass "review from the fork point shows only the stack" || fail "fork-point review package: $files"
+(cd "$repo" && "$REVIEW_PKG" spec.md "$(jj log -r main --no-graph -T 'commit_id')" @ "$TEST_ROOT/trunk.diff" >/dev/null)
+[[ "$(cat "$TEST_ROOT/trunk.diff")" == *l.txt* ]] && pass "fixture: diffing from the trunk commit shows the sibling landing (the hazard)" || fail "fixture did not reproduce the hazard"
+
 # Regression: pre-origin topology where trunk() carries an extra local label (e.g.
 # `fork-base`). The bookmark must come from a main/master/trunk label, never that one.
 pre="$TEST_ROOT/pre-origin"; mkdir -p "$pre/repo"; git init -q --bare "$pre/upstream.git"
@@ -160,7 +233,7 @@
   && jj bookmark untrack main@upstream >/dev/null 2>&1)
 labels="$(cd "$pre/repo" && jj log -r 'trunk()' --no-graph -T 'bookmarks')"
 [[ "$labels" == fork-base* ]] && pass "fixture: fork-base is the first label on trunk()" || fail "fixture labels unexpected: $labels"
-assert_eq "$(cd "$pre/repo" && "$TRUNK_REV")" "trunk() main" "never returns a co-located non-trunk label as the trunk bookmark"
+assert_eq "$(cd "$pre/repo" && "$TRUNK_REV")" "main main" "never returns a co-located non-trunk label as the trunk bookmark"
 
 # Case 4: not a jj repo -> exit 2 with the contract message.
 plain="$TEST_ROOT/plain"; mkdir -p "$plain"
```

- [ ] **Step 2: Run it to verify it fails**

Run: `bash tests/starting-a-change/test-fresh-change.sh`
Expected: `STATUS: FAILED (20)`. The old script prefers `main@origin`, so the shown stack and the discard target include the landed change, and a diverged or behind `main` resolves instead of stopping. The old `fresh-change` reuses an empty `@` on a stale trunk and starts work on a stack forked from one, and `--fork-point` does not exist.

- [ ] **Step 3: Replace the resolver**

Replace the whole of `skills/starting-a-change/scripts/trunk-rev` (keep it executable):

```bash
#!/usr/bin/env bash
# Print the local trunk bookmark as a revset, plus its name.
#
# The stack boundary is the local trunk bookmark: work landed locally moves it,
# and nothing pushes it. A remote bookmark is not the boundary. With unpushed
# local landings, `main@origin..@` would include changes that already landed,
# so shaping could squash them and discard could abandon them. jj's built-in
# trunk() is no better: it only sees remote bookmarks, picks by committer
# timestamp (in a fork it flips to upstream's main whenever upstream is newer),
# and falls back to root() in a local-only repo.
#
# Resolution: the first local bookmark named main, master, or trunk. If
# `<name>@origin` exists, it must be the local bookmark or one of its
# ancestors (local is equal or ahead with unpushed landings). Local behind or
# diverged from origin exits 1: the boundary is ambiguous until the operator
# reconciles it.
#
# Output: `<revset> <bookmark>`, e.g. `main main`. Skills substitute the
# revset wherever they say trunk(). Exit 1 with a message when nothing
# qualifies or the bookmark disagrees with origin.
#
# With --fork-point REV, print instead the commit ID of fork_point(trunk | REV):
# where the stack ending at REV left trunk. Review diffs start there. Diffing
# from the trunk commit itself would show changes landed on trunk beside the
# stack as deletions.
#
# Usage: trunk-rev [--fork-point REV]
set -euo pipefail

fork_rev=
case "${1:-}" in
  '') ;;
  --fork-point)
    fork_rev=${2:?usage: trunk-rev [--fork-point REV]}
    ;;
  *)
    echo "usage: trunk-rev [--fork-point REV]" >&2
    exit 2
    ;;
esac

name=
for candidate in main master trunk; do
  if [ -n "$(jj log -r "present(bookmarks(exact:\"$candidate\"))" --no-graph -T 'change_id.short()' 2>/dev/null)" ]; then
    name=$candidate
    break
  fi
done

if [ -z "$name" ]; then
  echo "no trunk: no local main/master/trunk bookmark. Create one on the base commit: jj bookmark create main -r <base> (or jj bookmark track main@origin)" >&2
  exit 1
fi

local_rev="bookmarks(exact:\"$name\")"
origin_rev="remote_bookmarks(exact:\"$name\", exact:\"origin\")"
# A tracked bookmark that diverged from its remote becomes conflicted on fetch
# and resolves to several commits.
if [ "$(jj log -r "$local_rev" --no-graph -T 'commit_id ++ "\n"' | grep -c .)" -ne 1 ]; then
  echo "trunk: local $name is conflicted (it diverged from a remote). Reconcile it before finishing: jj bookmark set $name -r <commit>" >&2
  exit 1
fi
if [ -n "$(jj log -r "present($origin_rev)" --no-graph -T 'change_id.short()' 2>/dev/null)" ]; then
  if [ -z "$(jj log -r "$origin_rev & ::$local_rev" --no-graph -T 'change_id.short()' 2>/dev/null)" ]; then
    if [ -n "$(jj log -r "$local_rev & ::$origin_rev" --no-graph -T 'change_id.short()' 2>/dev/null)" ]; then
      echo "trunk: local $name is behind $name@origin. Move it before finishing: jj bookmark set $name -r $name@origin" >&2
    else
      echo "trunk: local $name and $name@origin have diverged. Reconcile them before finishing; the stack boundary is ambiguous." >&2
    fi
    exit 1
  fi
fi

if [ -n "$fork_rev" ]; then
  jj log -r "fork_point($local_rev | ($fork_rev))" --no-graph -T 'commit_id ++ "\n"'
  exit 0
fi
echo "$name $name"
```

Replace the whole of `skills/starting-a-change/scripts/fresh-change` (keep it executable):

```bash
#!/usr/bin/env bash
# Put new work on a fresh jj change without absorbing anything in flight.
#
# The stack (spec, plan, earlier commits) lives between the local trunk and @
# and must stay in the working copy — never reset to trunk. What must NOT be
# absorbed is loose, undescribed work-in-progress sitting in @. Three cases:
#
#   @ empty + undescribed   -> reuse it (the normal state after `jj commit`)
#   @ described             -> `jj new` on top (deliberate work; build on it)
#   @ non-empty + undescribed -> `jj new @-` (sibling: the WIP stays in its own
#                              change, untouched, and our work starts beside it)
#
# The base the work would sit on (@- when reusing or stepping beside WIP, @
# when building on a described change) must descend from the local trunk that
# trunk-rev resolves, the same boundary finishing lands on:
#
#   base descends from trunk          -> the case above
#   base is behind trunk, no stack    -> `jj new <trunk>` (`new-on-trunk`); any
#                                        WIP stays in its own change
#   base carries a stack forked from  -> exit 1 with the rebase command; the
#   an older trunk                       stack is the user's to move
#
# A trunk that is behind, diverged from, or conflicted with origin exits 1
# with trunk-rev's message. A repository with no trunk bookmark only warns.
#
# Prints one line: `<change-id> <reused|new-on-top|new-beside-wip|new-on-trunk> [<wip-change-id>]`.
#
# Usage: fresh-change
set -euo pipefail

if ! jj root >/dev/null 2>&1; then
  echo "This isn't a jj repo. Run \`jj git init --colocate\` and re-run, or tell me to continue without VCS steps." >&2
  exit 2
fi

trunk=
set +e
tr_out=$("$(dirname "$0")/trunk-rev" 2>&1)
tr_code=$?
set -e
if [ "$tr_code" -eq 0 ]; then
  trunk=${tr_out%% *}
elif [[ "$tr_out" == "no trunk:"* ]]; then
  echo "warning: no trunk found (no local main/master/trunk bookmark). Before finishing: jj bookmark create main -r <base>" >&2
else
  echo "$tr_out" >&2
  exit 1
fi

state=$(jj log -r @ --no-graph -T 'if(empty, "empty", "nonempty") ++ " " ++ if(description, "described", "undescribed") ++ " " ++ change_id.short()')
read -r fill desc wc_id <<<"$state"

case "$fill $desc" in
  "empty undescribed") base='@-' ;;
  *" described") base='@' ;;
  *) base='@-' ;;
esac

new_id() { jj log -r @ --no-graph -T 'change_id.short()'; }

if [ -n "$trunk" ] && [ -z "$(jj log -r "($trunk) & ::($base)" --no-graph -T 'change_id.short()')" ]; then
  if [ -n "$(jj log -r "($base) & ::($trunk)" --no-graph -T 'change_id.short()')" ]; then
    jj new --quiet "$trunk"
    if [ "$fill $desc" = "nonempty undescribed" ]; then
      echo "$(new_id) new-on-trunk $wc_id"
    else
      echo "$(new_id) new-on-trunk"
    fi
    exit 0
  fi
  roots=$(jj log -r "roots(($trunk)..($base))" --no-graph -T '"-s " ++ change_id.short() ++ " "')
  echo "the stack under @ is not based on local $trunk (it forked from an older trunk). Rebase it first: jj rebase ${roots}-d $trunk" >&2
  exit 1
fi

case "$fill $desc" in
  "empty undescribed")
    echo "$wc_id reused"
    ;;
  *" described")
    jj new --quiet
    echo "$(new_id) new-on-top"
    ;;
  "nonempty undescribed")
    jj new --quiet '@-'
    echo "$(new_id) new-beside-wip $wc_id"
    ;;
esac
```

- [ ] **Step 4: Run it to verify it passes**

Run: `bash tests/starting-a-change/test-fresh-change.sh`
Expected: `STATUS: PASSED`, 60 `[PASS]` lines.

- [ ] **Step 5: Update finishing and the docs**

Apply this change to `skills/starting-a-change/SKILL.md`:

```diff
--- a/skills/starting-a-change/SKILL.md
+++ b/skills/starting-a-change/SKILL.md
@@ -46,9 +46,11 @@
 | described | `jj new` on top (`new-on-top`) | a described change is deliberate work; build on it |
 | non-empty + undescribed | `jj new @-` (`new-beside-wip <id>`) | loose WIP stays in its own change beside yours, untouched |
 
-Never `jj new trunk()` — that orphans the spec and plan committed above trunk. Never edit, squash, or abandon the user's change.
+The work must sit on the local trunk bookmark from `scripts/trunk-rev`, the same boundary finishing lands on. If the base is an older trunk commit with nothing of yours above it (another workspace landed since), the script starts on the current trunk instead (`new-on-trunk`, with the WIP id if it stepped aside). If a stack above the base forked from an older trunk, it exits 1 with the `jj rebase` command; relay it and stop. The stack is the user's to move.
 
-If the script warns that no trunk was found (a brand-new local repo: `trunk()` resolves to `root()` and there is no local `main`/`master`/`trunk` bookmark), relay the fix now so finishing works later: `jj bookmark create main -r <base>`. No config change is needed — `scripts/trunk-rev` resolves the trunk at runtime and every skill uses its output where it says `trunk()`.
+Never run `jj new trunk()` (or `jj new <trunk>`) yourself — with a spec or plan committed above trunk, that orphans them. Only the script moves to trunk, and only when nothing of yours sits above the base. Never edit, squash, or abandon the user's change.
+
+If the script exits 1 with trunk-rev's message (local trunk behind, diverged from, or conflicted with `<name>@origin`), relay that message and stop. The boundary is ambiguous until the user reconciles it: behind means `jj bookmark set <name> -r <name>@origin`; diverged or conflicted means rebasing the local-only landings onto `<name>@origin` and setting the bookmark to the result. If it only warns that no trunk was found (a brand-new local repo with no local `main`/`master`/`trunk` bookmark), relay the fix now so finishing works later: `jj bookmark create main -r <base>`. No config change is needed — `scripts/trunk-rev` resolves the trunk at runtime and every skill uses its output where it says `trunk()`.
 
 ## Step 3: Associate Kata work
 
```

Apply this change to `skills/finishing-a-change-stack/SKILL.md`:

````diff
--- a/skills/finishing-a-change-stack/SKILL.md
+++ b/skills/finishing-a-change-stack/SKILL.md
@@ -47,13 +47,13 @@
 
 ## Step 3: Show the Stack
 
-Resolve the trunk first — jj's built-in `trunk()` only sees remote bookmarks and falls back to `root()` in a local-only repo:
+Resolve the trunk first. The stack boundary is the local trunk bookmark: landing moves it locally and nothing pushes it, so `main@origin..@` would include changes that already landed. jj's built-in `trunk()` is no better; it only sees remote bookmarks and falls back to `root()` in a local-only repo.
 
 ```bash
 read -r TRUNK TRUNK_BOOKMARK < <(<starting-a-change skill dir>/scripts/trunk-rev)
 ```
 
-It prints e.g. `main@origin main`, `trunk() main`, or `main main` (local-only repo). If it fails, stop and have the user run `jj bookmark create main -r <base>`, then start Step 3 over. Use `$TRUNK` wherever this skill writes `trunk()`.
+It prints e.g. `main main`. If it fails, stop and relay its message: no trunk bookmark (have the user run `jj bookmark create main -r <base>`), or local trunk behind, diverged from, or conflicted with `<bookmark>@origin` (the user reconciles it; never pick a side yourself). Then start Step 3 over. Use `$TRUNK` wherever this skill writes `trunk()`: stack display, conflict checks, shaping, rebase, bookmark update, and discard.
 
 ```bash
 jj log -r "$TRUNK..@"
````

Apply this change to `skills/subagent-driven-development/SKILL.md`:

```diff
--- a/skills/subagent-driven-development/SKILL.md
+++ b/skills/subagent-driven-development/SKILL.md
@@ -471,7 +471,7 @@
 ## Final Review
 
 The final whole-branch review gets a package too: run
-`scripts/review-package PLAN_FILE MERGE_BASE @`. MERGE_BASE is the trunk's commit ID: resolve the trunk with the starting-a-change skill's `scripts/trunk-rev` (jj's built-in `trunk()` is `root()` in a local-only repo), then `jj log -r "$TRUNK" --no-graph -T 'commit_id'`. Include the
+`scripts/review-package PLAN_FILE MERGE_BASE @`. MERGE_BASE is where the stack left trunk: `MERGE_BASE=$(<starting-a-change skill dir>/scripts/trunk-rev --fork-point @)`. Not the trunk commit itself: when another workspace landed on local trunk beside the stack, diffing from trunk shows that landing as deletions. If it exits 1, the local trunk disagrees with origin; relay its message and stop. Include the
 printed path in the final review dispatch, so the final reviewer reads
 one file instead of re-deriving the stack diff with jj commands. Dispatch
 on the most capable available model (see Model Selection), using
```

Apply this change to `skills/requesting-code-review/SKILL.md`:

````diff
--- a/skills/requesting-code-review/SKILL.md
+++ b/skills/requesting-code-review/SKILL.md
@@ -31,7 +31,7 @@
 BASE=$(jj log -r @- --no-graph -T 'commit_id')   # with @ empty, before implementing
 ```
 
-Never derive it afterwards: after `jj commit`, `@` is a fresh empty change and `@-` is the work itself, so `@-..@` is an empty diff. If you did not record it, use the trunk from the starting-a-change skill's `scripts/trunk-rev`: `BASE=$(jj log -r "$TRUNK" --no-graph -T 'commit_id')`. HEAD is always `@`.
+Never derive it afterwards: after `jj commit`, `@` is a fresh empty change and `@-` is the work itself, so `@-..@` is an empty diff. If you did not record it, use where the stack left trunk: `BASE=$(<starting-a-change skill dir>/scripts/trunk-rev --fork-point @)`. Not the trunk commit itself, which shows anything landed on trunk since as deletions. A recorded BASE always wins. HEAD is always `@`.
 
 **2. Dispatch code reviewer subagent:**
 
````

Apply this change to `evals/run`:

```diff
--- a/evals/run
+++ b/evals/run
@@ -4,6 +4,8 @@
 #   evals/run setup <scenario>     build the fixture in a temp dir, run pre-checks,
 #                                  print the story and the directory to start your agent in
 #   evals/run post <scenario> <dir> run post-checks against the fixture after the session
+#   evals/run teardown <dir>       remove the fixture and its temp directory (after post,
+#                                  and after a failed or abandoned run)
 #   evals/run list                 scenarios and their status
 #
 # Grade the acceptance criteria in story.md yourself from the transcript;
@@ -41,7 +43,7 @@
     echo
     echo "Fixture ready. Start your agent in:"
     echo "  cd $fixture"
-    echo "Afterwards: evals/run post $scenario $fixture"
+    echo "Afterwards: evals/run post $scenario $fixture && evals/run teardown $fixture"
     ;;
   post)
     scenario=${1:?scenario name}; fixture=${2:?fixture dir}
@@ -51,6 +53,19 @@
     . "$here/lib/checks.sh"
     run-checks post "$dir"
     ;;
+  teardown)
+    fixture=${1:?fixture dir}
+    # Only a directory setup made: <mktemp dir under TMPDIR>/repo. Anything else is refused.
+    tmp_root=$(cd "${TMPDIR:-/tmp}" && pwd -P)
+    parent=$(cd "$(dirname "$fixture")" 2>/dev/null && pwd -P) || { echo "no such fixture: $fixture" >&2; exit 2; }
+    case "$parent" in
+      "$tmp_root"/tmp.*) ;;
+      *) echo "refusing to remove $fixture: not an evals/run fixture under ${TMPDIR:-/tmp}" >&2; exit 2;;
+    esac
+    [ "$(basename "$fixture")" = repo ] || { echo "refusing to remove $fixture: fixtures end in /repo" >&2; exit 2; }
+    rm -rf "$parent"
+    echo "removed $parent"
+    ;;
   *)
-    sed -n '2,10p' "$0"; exit 2;;
+    sed -n '2,12p' "$0"; exit 2;;
 esac
```

Apply this change to `evals/README.md`:

````diff
--- a/evals/README.md
+++ b/evals/README.md
@@ -23,6 +23,7 @@
 #   builds a throwaway jj repo, runs pre-checks, prints the story and the dir
 cd <printed dir>            # start your agent here and play the story's human
 evals/run post finishing-stack-no-unprompted-discard <printed dir>
+evals/run teardown <printed dir>   # always, even after a failed or abandoned run
 ```
 
 Verdict = every acceptance criterion met (your call, from the transcript)
````

Apply this change to `CLAUDE.md`:

```diff
--- a/CLAUDE.md
+++ b/CLAUDE.md
@@ -8,9 +8,9 @@
 
 > This isn't a jj repo. Run `jj git init --colocate` and re-run, or tell me to continue without VCS steps.
 
-Work starts on a fresh change via `starting-a-change`'s `scripts/fresh-change` (reuse an empty `@`, `jj new` on described work, `jj new @-` beside loose WIP — never `jj new trunk()`, which orphans the spec/plan stack). Artifacts (roadmap, spec, plan) are committed by fileset: `jj commit <path> -m …`. Ledgers record change IDs; review boundaries (SDD BASE / FIX_BASE) record commit IDs, which stay valid after rewrites. Do not emit `jj git push`, bookmark moves on `main`/`trunk()`, or `jj abandon` except inside finishing-a-change-stack's explicit user-chosen options.
+Work starts on a fresh change via `starting-a-change`'s `scripts/fresh-change` (reuse an empty `@`, `jj new` on described work, `jj new @-` beside loose WIP, all on the local trunk bookmark; only the script moves to trunk, and only when nothing of yours sits above the base — never `jj new trunk()` yourself, which orphans the spec/plan stack). Artifacts (roadmap, spec, plan) are committed by fileset: `jj commit <path> -m …`. Ledgers record change IDs; review boundaries (SDD BASE / FIX_BASE) record commit IDs, which stay valid after rewrites. Do not emit `jj git push`, bookmark moves on `main`/`trunk()`, or `jj abandon` except inside finishing-a-change-stack's explicit user-chosen options.
 
-jj's built-in `trunk()` only sees remote bookmarks and is `root()` in a local-only repo. Skills that need a real trunk (finishing, SDD final review) resolve it at runtime with `starting-a-change`'s `scripts/trunk-rev` (prefers `main@origin`, then the built-in when it carries a main/master/trunk label, then a local `main`/`master`/`trunk`); no repo config write is required or attempted. In this repo the built-in flips to `main@upstream` whenever upstream is newer — see `docs/upstream-sync.md`.
+jj's built-in `trunk()` only sees remote bookmarks and is `root()` in a local-only repo. Skills that need a real trunk (finishing, SDD final review) resolve it at runtime with `starting-a-change`'s `scripts/trunk-rev`, which returns the local `main`/`master`/`trunk` bookmark: local landings move it and nothing pushes it. It exits 1 when the local bookmark is behind, diverged from, or conflicted with `<name>@origin`; ahead is fine. Review bases with no recorded commit use `trunk-rev --fork-point @`, where the stack left trunk. No repo config write is required or attempted. In this repo the built-in flips to `main@upstream` whenever upstream is newer — see `docs/upstream-sync.md`.
 
 ## Tracking and artifact layout
 
```

Apply this change to `docs/upstream-sync.md`:

```diff
--- a/docs/upstream-sync.md
+++ b/docs/upstream-sync.md
@@ -7,7 +7,7 @@
 
 The stack is exactly `fork-base..main`. Its first change is mechanical (prune harness plumbing and the official-listing pipeline, global rename via `scripts/fork-rename.mjs`, simplified Claude hook); the rest are semantic (jj port, roadmap layer, docs). `jj log -r 'fork-base..main'` lists them.
 
-Remotes: `upstream` = obra/superpowers, `origin` = codyw912/sjujperpowers. Do not rely on jj's built-in `trunk()` here: it is `latest(main@origin | main@upstream | …)` by committer timestamp, so it flips to `main@upstream` whenever upstream is newer. The fork's own skills resolve the trunk with `skills/starting-a-change/scripts/trunk-rev`, which prefers `main@origin`. If other tooling needs `trunk()` to be stable, pin it in this repo's config: `revset-aliases."trunk()" = "main@origin"`.
+Remotes: `upstream` = obra/superpowers, `origin` = codyw912/sjujperpowers. Do not rely on jj's built-in `trunk()` here: it is `latest(main@origin | main@upstream | …)` by committer timestamp, so it flips to `main@upstream` whenever upstream is newer. The fork's own skills resolve the trunk with `skills/starting-a-change/scripts/trunk-rev`, which returns the local `main` bookmark and stops if it is behind or diverged from `main@origin`. After pushing from another machine, `jj git fetch` leaves local `main` behind: `jj bookmark set main -r main@origin`. If both sides moved, local `main` is conflicted or diverged: rebase the local-only landings onto `main@origin` (`jj rebase -s <first local landing> -d main@origin`), then `jj bookmark set main -r <rebased head>`. If other tooling needs `trunk()` to be stable, pin it in this repo's config: `revset-aliases."trunk()" = "main@origin"`.
 
 ## Procedure
 
```

Apply this change to `docs/testing.md`:

```diff
--- a/docs/testing.md
+++ b/docs/testing.md
@@ -14,7 +14,7 @@
 - `tests/pi/` — Pi extension.
 - `tests/codex/` — Codex marketplace manifest.
 - `tests/claude-code/` — SDD tests plus `test-sdd-workspace.sh` (requires `jj`).
-- `tests/starting-a-change/` — `fresh-change`, `trunk-rev`, `add-workspace`: spec/plan stay in the working copy, loose WIP is never absorbed, trunk resolves without config, workspaces descend from a committed ignore entry (requires `jj`).
+- `tests/starting-a-change/` — `fresh-change`, `trunk-rev`, `add-workspace`: spec/plan stay in the working copy, loose WIP is never absorbed, trunk is the local bookmark (ahead of origin is fine; behind, diverged, or conflicted stops), new work starts on it, review bases come from its fork point, workspaces descend from a committed ignore entry (requires `jj`).
 - `tests/tracking-providers/` — provider normalization, checked Kata preflight, plan parsing, idempotent materialization, independent `file + kata` composition, and plan-root selection guards.
 - `tests/systematic-debugging/` — find-polluter helper.
 - `tests/writing-skills/` — skill graph rendering.
@@ -28,7 +28,7 @@
 
 ## Skill behavior evals
 
-`evals/` holds a small set of scenarios ported from upstream's [superpowers-evals](https://github.com/prime-radiant-inc/superpowers-evals) to jj, without the Quorum harness: you build the fixture with `evals/run setup <scenario>`, play the human per `story.md` in the harness under test, then `evals/run post` for the deterministic backstop. Grading the acceptance criteria is manual. Details and the scenario list are in `evals/README.md`.
+`evals/` holds a small set of scenarios ported from upstream's [superpowers-evals](https://github.com/prime-radiant-inc/superpowers-evals) to jj, without the Quorum harness: you build the fixture with `evals/run setup <scenario>`, play the human per `story.md` in the harness under test, then `evals/run post` for the deterministic backstop. Grading the acceptance criteria is manual; `evals/run teardown <dir>` removes the fixture afterwards. Details and the scenario list are in `evals/README.md`.
 
 ## Tracking-provider checks
 
```

`AGENTS.md` is a symlink to `CLAUDE.md`; edit `CLAUDE.md` only.

- [ ] **Step 6: Commit**

```bash
jj commit skills/starting-a-change tests/starting-a-change/test-fresh-change.sh skills/finishing-a-change-stack/SKILL.md skills/subagent-driven-development/SKILL.md skills/requesting-code-review/SKILL.md evals/run evals/README.md CLAUDE.md docs/upstream-sync.md docs/testing.md -m "Use the local trunk bookmark as the stack boundary"
```

### Task 2: Risk policy parser and path classification

**Files:**
- Create: `skills/verifying-by-risk/scripts/jj.mjs`
- Create: `skills/verifying-by-risk/scripts/policy.mjs`
- Test: `tests/verifying-by-risk/test-policy.mjs`

**Interfaces:**
- Produces (`jj.mjs`): `TIERS`, `GRADES`, `fail(message, code = 2)`, `jj(repo, args, { allowFail })`, `rev(repo, revset, template)`, `root(repo)`, `resolveCommit(repo, revset) → 40-char id | null`, `flag(argv, name)`, `flags(argv, name)`, `repoArg(argv)`, `snapshot(repo)`, `resolveHead(repo, requested?) → { commit, change }`, `resolveTrunk(repo) → { bookmark, commit }` (runs Task 1's `trunk-rev`; exit 2 with its message on failure), `forkPoint(repo, trunkCommit, headCommit) → commit`, `changedPaths(repo, from, to) → [{ status, from, to }]`, `maxTier(a, b)`.
- Produces (`policy.mjs`): `BUILTIN_PROTECTED`, `globToRegExp(glob) → RegExp`, `parseRiskToml(text) → { defaultTier, testCommand, protected: [{ glob, re }], rules: [{ tier, globs: [{ glob, re }] }] }` (`testCommand` is the quoted top-level `test`, or null; throws on any malformed input), `classifyPaths(rows, policy | null) → { paths, protectedPaths, protected, computedTier }`.

- [ ] **Step 1: Write the failing test**

Create `tests/verifying-by-risk/test-policy.mjs`:

```js
import { test } from 'node:test';
import assert from 'node:assert/strict';
import {
  classifyPaths,
  globToRegExp,
  parseRiskToml,
} from '../../skills/verifying-by-risk/scripts/policy.mjs';

const BASE = 'version = 1\ndefault = "medium"\n';

test('multi-line arrays, comments, and trailing commas parse', () => {
  const policy = parseRiskToml(`${BASE}protected = [
  "migrations/**", # schema
  "src/auth/**",
]

[[rule]]
paths = ["docs/**", "*.md"] # prose
tier = "low"
`);
  assert.deepEqual(
    policy.protected.map((item) => item.glob),
    ['migrations/**', 'src/auth/**'],
  );
  assert.deepEqual(
    policy.rules.map((rule) => [rule.tier, rule.globs.map((g) => g.glob)]),
    [['low', ['docs/**', '*.md']]],
  );
});

test('a # inside a string is not a comment', () => {
  const policy = parseRiskToml(`${BASE}protected = ["a#b/**"]\n`);
  assert.equal(policy.protected[0].glob, 'a#b/**');
});

test('malformed policies are rejected', () => {
  for (const [body, message] of [
    ['default = "low"\n', /version/],
    ['version = 1\n', /default/],
    [`${BASE}default = "low"\n`, /duplicate/],
    [`${BASE}owner = "x"\n`, /unknown key/],
    [`${BASE}[[rule]]\npaths = ["a"]\ntier = "urgent"\n`, /tier/],
    [`${BASE}[[rule]]\ntier = "low"\n`, /paths/],
    [`${BASE}protected = ["a"\n`, /expected|unterminated/],
    [`${BASE}protected = ["a"] "b"\n`, /expected nl/],
  ]) {
    assert.throws(() => parseRiskToml(body), message, body);
  }
});

test('glob semantics', () => {
  const cases = [
    ['.hk/**', '.hk/base/rust.pkl', true],
    ['.hk/**', '.hk', false],
    ['*.md', 'README.md', true],
    ['*.md', 'docs/a.md', false],
    ['**/*.md', 'docs/a.md', true],
    ['**/*.md', 'a.md', true],
    ['.agents/skills/verify-*/scripts/**', '.agents/skills/verify-x/scripts/run.sh', true],
    ['.agents/skills/verify-*/scripts/**', '.agents/skills/verify-x/SKILL.md', false],
    ['src/a?.rs', 'src/ab.rs', true],
    ['src/a?.rs', 'src/a/.rs', false],
  ];
  for (const [glob, file, expected] of cases)
    assert.equal(globToRegExp(glob).test(file), expected, `${glob} ${file}`);
});

test('no policy is high even with no changed paths', () => {
  assert.equal(classifyPaths([], null).computedTier, 'high');
  assert.equal(
    classifyPaths([{ status: 'modified', from: 'a', to: 'a' }], null).computedTier,
    'high',
  );
});

test('highest tier wins and a rename counts both sides', () => {
  const policy = parseRiskToml(
    `${BASE}[[rule]]\npaths = ["docs/**"]\ntier = "low"\n[[rule]]\npaths = ["src/**"]\ntier = "high"\n`,
  );
  const result = classifyPaths([{ status: 'renamed', from: 'src/x.rs', to: 'docs/x.rs' }], policy);
  assert.equal(result.computedTier, 'high');
  assert.equal(
    classifyPaths([{ status: 'added', from: 'docs/a', to: 'docs/a' }], policy).computedTier,
    'low',
  );
});

test('top-level test command is parsed; absent means null', () => {
  assert.equal(parseRiskToml(`${BASE}test = "node --test tests/"\n`).testCommand, 'node --test tests/');
  assert.equal(parseRiskToml(BASE).testCommand, null);
  assert.equal(
    parseRiskToml(`${BASE}test = "cargo test --workspace # all"\n`).testCommand,
    'cargo test --workspace # all',
  );
});

test('test command must be a non-empty string, once, at the top level', () => {
  for (const body of [
    `${BASE}test = ""\n`,
    `${BASE}test = "   "\n`,
    `${BASE}test = ["node", "--test"]\n`,
    `${BASE}test = true\n`,
    `${BASE}test = 1\n`,
    `${BASE}test = "a"\ntest = "b"\n`,
    `${BASE}[[rule]]\npaths = ["a"]\ntier = "low"\ntest = "node --test"\n`,
  ]) {
    assert.throws(() => parseRiskToml(body), undefined, body);
  }
  for (const body of [`${BASE}test = true\n`, `${BASE}test = 1\n`])
    assert.throws(() => parseRiskToml(body), /test must be a quoted string/, body);
});

test('verification-skill, hk, and devenv files are built-in protected', () => {
  const policy = parseRiskToml(`${BASE}`);
  for (const file of [
    'devenv.nix',
    '.config/hk.pkl',
    '.claude/skills/verify-x',
    '.agents/skills/verify-x/SKILL.md',
    '.agents/skills/verify-x/features/a.md',
    '.agents/skills/verify-x/features/deep/b.md',
  ]) {
    const result = classifyPaths([{ status: 'modified', from: file, to: file }], policy);
    assert.equal(result.protected, true, file);
    assert.deepEqual(result.protectedPaths, [file]);
  }
  for (const file of ['devenv.nix.bak', '.agents/skills/other/SKILL.md', '.agents/skills/verify-x/README.md', '.claude/skills/other', '.config/hk.local.pkl']) {
    const result = classifyPaths([{ status: 'modified', from: file, to: file }], policy);
    assert.equal(result.protected, false, file);
  }
});

test('a protected path renamed away is still protected', () => {
  const result = classifyPaths(
    [{ status: 'renamed', from: 'devenv.nix', to: 'docs/devenv.txt' }],
    parseRiskToml(BASE),
  );
  assert.equal(result.protected, true);
  assert.deepEqual(result.protectedPaths, ['devenv.nix', 'docs/devenv.txt']);
});
```

- [ ] **Step 2: Run it to verify it fails**

Run: `node --test tests/verifying-by-risk/test-policy.mjs`
Expected: FAIL with `Cannot find module '…/skills/verifying-by-risk/scripts/policy.mjs'`

- [ ] **Step 3: Implement the Jujutsu helpers and the policy module**

Create `skills/verifying-by-risk/scripts/jj.mjs`:

```js
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

export const TIERS = ['low', 'medium', 'high'];
export const GRADES = [
  'failed',
  'blocked',
  'type-check-only',
  'unit-tested',
  'behavior-tested',
  'live-verified',
];

export function fail(message, code = 2) {
  process.stderr.write(`${message}\n`);
  process.exit(code);
}

export function jj(repo, args, { allowFail = false } = {}) {
  const result = spawnSync('jj', ['-R', repo, '--quiet', ...args], { encoding: 'utf8' });
  if (result.error) fail(`jj ${args[0]}: ${result.error.message}`);
  if (result.status !== 0 && !allowFail) {
    fail((result.stderr || result.stdout || `jj ${args.join(' ')} failed`).trim());
  }
  return result;
}

export function rev(repo, revset, template) {
  const result = jj(repo, ['log', '-r', revset, '--no-graph', '-T', template], { allowFail: true });
  if (result.status !== 0) return null;
  return result.stdout;
}

export function root(repo) {
  const result = jj(repo, ['root']);
  return result.stdout.trim();
}

export function resolveCommit(repo, revset) {
  const id = rev(repo, revset, 'commit_id');
  if (!id) return null;
  const trimmed = id.trim();
  return trimmed.length === 40 ? trimmed : null;
}

export function flag(argv, name) {
  const index = argv.indexOf(name);
  if (index === -1) return undefined;
  const value = argv[index + 1];
  if (value === undefined || value.startsWith('--')) fail(`missing value for ${name}`);
  return value;
}

export function flags(argv, name) {
  const values = [];
  for (let i = 0; i < argv.length; i += 1) {
    if (argv[i] === name) {
      const value = argv[i + 1];
      if (value === undefined || value.startsWith('--')) fail(`missing value for ${name}`);
      values.push(value);
    }
  }
  return values;
}

export function repoArg(argv) {
  return flag(argv, '--repo') || process.cwd();
}

// Snapshot first so a file written just before this process cannot rewrite @ afterwards.
export function snapshot(repo) {
  jj(repo, ['status']);
}

// @ is empty when jj reports empty=true. Same rule as finishing-a-change-stack.
export function resolveHead(repo, requested) {
  const revset = requested || '@';
  let commit = resolveCommit(repo, revset);
  if (!commit) fail(`cannot resolve head ${requested || '@'}`);
  if (!requested && rev(repo, commit, 'empty').trim() === 'true') {
    commit = resolveCommit(repo, '@-');
    if (!commit) fail('cannot resolve @-');
  }
  const change = rev(repo, commit, 'change_id');
  if (!change || !change.trim()) fail(`cannot resolve change id for ${commit}`);
  return { commit, change: change.trim() };
}

const TRUNK_REV = fileURLToPath(
  new URL('../../starting-a-change/scripts/trunk-rev', import.meta.url),
);

// The local trunk bookmark, resolved by the same script finishing-a-change-stack
// uses, so the classified range and the stack finishing shows never differ.
export function resolveTrunk(repo) {
  const result = spawnSync('bash', [TRUNK_REV], { cwd: repo, encoding: 'utf8' });
  if (result.error) fail(`trunk-rev: ${result.error.message}`);
  if (result.status !== 0) fail((result.stderr || 'trunk-rev failed').trim());
  const [revset, bookmark] = result.stdout.trim().split(' ');
  const commit = resolveCommit(repo, revset);
  if (!commit) fail(`cannot resolve trunk ${revset}`);
  return { bookmark, commit };
}

export function forkPoint(repo, trunkCommit, headCommit) {
  const commit = resolveCommit(repo, `fork_point(${trunkCommit} | ${headCommit})`);
  if (!commit) fail('cannot resolve fork_point(trunk | head)');
  return commit;
}

export function changedPaths(repo, from, to) {
  const template =
    'json(status) ++ "\\t" ++ json(source.path()) ++ "\\t" ++ json(target.path()) ++ "\\n"';
  const result = jj(repo, ['diff', '--from', from, '--to', to, '-T', template]);
  const rows = [];
  for (const line of result.stdout.split('\n')) {
    if (!line) continue;
    const parts = line.split('\t');
    if (parts.length !== 3) fail(`unexpected jj diff line: ${line}`);
    rows.push({
      status: JSON.parse(parts[0]),
      from: JSON.parse(parts[1]),
      to: JSON.parse(parts[2]),
    });
  }
  return rows;
}

export function maxTier(left, right) {
  return TIERS.indexOf(left) >= TIERS.indexOf(right) ? left : right;
}
```

Create `skills/verifying-by-risk/scripts/policy.mjs`:

```js
import { TIERS, maxTier } from './jj.mjs';

export const BUILTIN_PROTECTED = [
  'hk.pkl',
  '.config/hk.pkl',
  '.hk/**',
  'nix/hk.nix',
  'scripts/update-hk',
  '.sjujperpowers/risk.toml',
  '.agents/skills/verify-*/SKILL.md',
  '.agents/skills/verify-*/features/**',
  '.agents/skills/verify-*/scripts/**',
  '.claude/skills/verify-*',
  '.github/workflows/**',
  'devenv.nix',
  'devenv.yaml',
  'devenv.lock',
];

// ** matches across slashes; "dir/**" matches files under dir, not dir itself.
// * and ? do not match /. * matches a leading dot. Match is full-path anchored.
export function globToRegExp(glob) {
  let pattern = '^';
  for (let i = 0; i < glob.length; i += 1) {
    const char = glob[i];
    const next = glob[i + 1];
    if (char === '*' && next === '*') {
      const after = glob[i + 2];
      if (after === '/') {
        pattern += '(?:.*/)?';
        i += 2;
      } else {
        pattern += '.*';
        i += 1;
      }
      continue;
    }
    if (char === '*') {
      pattern += '[^/]*';
      continue;
    }
    if (char === '?') {
      pattern += '[^/]';
      continue;
    }
    if ('\\^$+?.()|{}[]'.includes(char)) pattern += `\\${char}`;
    else pattern += char;
  }
  return new RegExp(`${pattern}$`);
}

// Tokenizer for the restricted risk.toml grammar: comments, bare keys,
// basic strings, bare integers/words, string arrays (may span lines), and
// [[rule]] headers.
function tokenize(text) {
  const tokens = [];
  let line = 1;
  let i = 0;
  while (i < text.length) {
    const char = text[i];
    if (char === '\n') {
      tokens.push({ type: 'nl', line });
      line += 1;
      i += 1;
    } else if (char === ' ' || char === '\t' || char === '\r') {
      i += 1;
    } else if (char === '#') {
      while (i < text.length && text[i] !== '\n') i += 1;
    } else if (text.startsWith('[[rule]]', i)) {
      tokens.push({ type: 'rule', line });
      i += 8;
    } else if ('[],='.includes(char)) {
      tokens.push({ type: char, line });
      i += 1;
    } else if (char === '"') {
      let value = '';
      i += 1;
      for (;;) {
        if (i >= text.length || text[i] === '\n')
          throw new Error(`unterminated string at line ${line}`);
        if (text[i] === '"') break;
        if (text[i] === '\\') {
          const escaped = { n: '\n', t: '\t', '\\': '\\', '"': '"' }[text[i + 1]];
          if (escaped === undefined) throw new Error(`bad escape at line ${line}`);
          value += escaped;
          i += 2;
        } else {
          value += text[i];
          i += 1;
        }
      }
      tokens.push({ type: 'string', value, line });
      i += 1;
    } else {
      const match = /^[A-Za-z0-9_-]+/.exec(text.slice(i));
      if (!match) throw new Error(`unexpected ${JSON.stringify(char)} at line ${line}`);
      tokens.push({ type: 'word', value: match[0], line });
      i += match[0].length;
    }
  }
  tokens.push({ type: 'nl', line });
  return tokens;
}

export function parseRiskToml(text) {
  const tokens = tokenize(text);
  let at = 0;
  const next = () => tokens[at++];
  const expect = (type) => {
    const token = next();
    if (token?.type !== type) throw new Error(`expected ${type} at line ${token?.line ?? 'end'}`);
    return token;
  };
  const value = () => {
    const token = next();
    if (token?.type === 'string' || token?.type === 'word') return token.value;
    if (token?.type !== '[') throw new Error(`expected value at line ${token?.line ?? 'end'}`);
    const items = [];
    for (;;) {
      while (tokens[at]?.type === 'nl') at += 1;
      if (tokens[at]?.type === ']') {
        at += 1;
        return items;
      }
      items.push(expect('string').value);
      while (tokens[at]?.type === 'nl') at += 1;
      if (tokens[at]?.type === ',') at += 1;
      else if (tokens[at]?.type !== ']')
        throw new Error(`expected , or ] at line ${tokens[at]?.line ?? 'end'}`);
    }
  };

  const top = {};
  const rules = [];
  let rule = null;
  while (at < tokens.length) {
    const token = next();
    if (token.type === 'nl') continue;
    if (token.type === 'rule') {
      rule = {};
      rules.push(rule);
      expect('nl');
      continue;
    }
    if (token.type !== 'word') throw new Error(`expected key at line ${token.line}`);
    expect('=');
    const target = rule ?? top;
    if (token.value in target)
      throw new Error(`duplicate key ${token.value} at line ${token.line}`);
    target[token.value] = value();
    if (target === top && token.value === 'test' && tokens[at - 1].type !== 'string')
      throw new Error(`test must be a quoted string at line ${token.line}`);
    expect('nl');
  }

  for (const key of Object.keys(top)) {
    if (!['version', 'default', 'test', 'protected'].includes(key))
      throw new Error(`unknown key ${key}`);
  }
  if (top.version !== '1') throw new Error('missing version = 1');
  if (!TIERS.includes(top.default)) throw new Error('default must be low, medium, or high');
  if (top.test !== undefined && (typeof top.test !== 'string' || !top.test.trim()))
    throw new Error('test must be a non-empty string');
  const protectedGlobs = top.protected ?? [];
  if (!Array.isArray(protectedGlobs)) throw new Error('protected must be a string array');
  for (const item of rules) {
    for (const key of Object.keys(item)) {
      if (!['paths', 'tier'].includes(key)) throw new Error(`unknown rule key ${key}`);
    }
    if (!Array.isArray(item.paths)) throw new Error('rule paths must be a string array');
    if (!TIERS.includes(item.tier)) throw new Error('rule tier must be low, medium, or high');
  }
  return {
    defaultTier: top.default,
    testCommand: top.test ?? null,
    protected: protectedGlobs.map((glob) => ({ glob, re: globToRegExp(glob) })),
    rules: rules.map((item) => ({
      tier: item.tier,
      globs: item.paths.map((glob) => ({ glob, re: globToRegExp(glob) })),
    })),
  };
}

export function classifyPaths(rows, policy) {
  const builtin = BUILTIN_PROTECTED.map((glob) => globToRegExp(glob));
  const extra = policy?.protected?.map((item) => item.re) || [];
  const protectedRes = [...builtin, ...extra];
  const paths = rows.map((row) => {
    const sides = [...new Set([row.from, row.to].filter(Boolean))];
    const sideTier = (side) => {
      if (!policy) return 'high';
      const rule = policy.rules.find((item) => item.globs.some((glob) => glob.re.test(side)));
      return rule ? rule.tier : policy.defaultTier;
    };
    const tier = sides.reduce((current, side) => maxTier(current, sideTier(side)), 'low');
    const protectedHit = sides.some((side) => protectedRes.some((re) => re.test(side)));
    return { status: row.status, from: row.from, to: row.to, tier, protected: protectedHit };
  });
  const protectedPaths = [
    ...new Set(paths.filter((row) => row.protected).flatMap((row) => [row.from, row.to])),
  ].sort();
  const computedTier = policy
    ? paths.reduce((tier, row) => maxTier(tier, row.tier), 'low')
    : 'high';
  return { paths, protectedPaths, protected: protectedPaths.length > 0, computedTier };
}
```

- [ ] **Step 4: Run it to verify it passes**

Run: `node --test tests/verifying-by-risk/test-policy.mjs`
Expected: PASS, 10 tests

- [ ] **Step 5: Commit**

```bash
jj commit skills/verifying-by-risk/scripts/jj.mjs skills/verifying-by-risk/scripts/policy.mjs tests/verifying-by-risk/test-policy.mjs -m "Add risk policy parser and path classification"
```

### Task 3: Whole-stack risk classification script

**Files:**
- Create: `skills/verifying-by-risk/scripts/classify.mjs`
- Create: `skills/verifying-by-risk/scripts/classify-risk.mjs` (executable)
- Test: `tests/verifying-by-risk/test-classify-risk.mjs`

**Interfaces:**
- Consumes: Task 2 `jj.mjs` and `policy.mjs`.
- Produces: `classify(repo, { head, range, raise })` in `classify.mjs`, and `node classify-risk.mjs [--repo R] [--head REV] [--range FROM..TO] [--raise low|medium|high]` → one JSON line `{ head: { commit, change }, range: { from, to }, policy: { bookmark, commit, riskToml, error? }, testCommand, tier, computedTier, protected, protectedPaths, paths: [{ status, from, to, tier, protected }] }`. Exit 2 on: no trunk or a trunk that `trunk-rev` rejects, nothing pending, unresolvable or non-matching `--range`, bad `--raise`.

- [ ] **Step 1: Write the failing test**

Create `tests/verifying-by-risk/test-classify-risk.mjs`:

```js
import { test, after } from 'node:test';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const SCRIPT = path.join(
  path.dirname(fileURLToPath(import.meta.url)),
  '../../skills/verifying-by-risk/scripts/classify-risk.mjs',
);

process.env.JJ_USER = 'vbr-test';
process.env.JJ_EMAIL = 'vbr-test@example.com';

// Every temp dir this file creates, removed once the file's tests finish.
const tempDirs = [];
after(() => {
  for (const dir of tempDirs) fs.rmSync(dir, { recursive: true, force: true });
});

function tempDir(prefix = 'vbr-') {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), prefix));
  tempDirs.push(dir);
  return dir;
}

function jj(repo, args) {
  const result = spawnSync('jj', args, { cwd: repo, encoding: 'utf8' });
  if (result.status !== 0) {
    throw new Error(
      `jj ${args.join(' ')} failed (${result.status}): ${result.stderr || result.stdout}`,
    );
  }
  return result;
}

function rev(repo, revset, template) {
  return jj(repo, ['log', '-r', revset, '--no-graph', '-T', template]).stdout.trim();
}

function initRepo() {
  const dir = tempDir();
  jj(dir, ['git', 'init', '--quiet', dir]);
  fs.writeFileSync(path.join(dir, 'README'), 'base\n');
  jj(dir, ['describe', '-m', 'base']);
  jj(dir, ['bookmark', 'create', 'main', '-r', '@']);
  return dir;
}

function classify(repo, args = []) {
  const result = spawnSync(process.execPath, [SCRIPT, '--repo', repo, ...args], {
    encoding: 'utf8',
  });
  let json = null;
  try {
    json = JSON.parse(result.stdout);
  } catch {
    json = null;
  }
  return { status: result.status, stdout: result.stdout, stderr: result.stderr, json };
}

function writeRisk(repo, body) {
  const dir = path.join(repo, '.sjujperpowers');
  fs.mkdirSync(dir, { recursive: true });
  fs.writeFileSync(path.join(dir, 'risk.toml'), body);
}

test('multi-change stack: earlier protected path, range.from is fork point', () => {
  const repo = initRepo();
  const mainCommit = rev(repo, 'main', 'commit_id');
  jj(repo, ['new', '-m', 'touch hk']);
  fs.mkdirSync(path.join(repo, '.hk'), { recursive: true });
  fs.writeFileSync(path.join(repo, '.hk', 'x.pkl'), 'x\n');
  jj(repo, ['new', '-m', 'later']);
  fs.writeFileSync(path.join(repo, 'later.txt'), 'later\n');
  const head = rev(repo, '@', 'commit_id');
  const out = classify(repo);
  assert.equal(out.status, 0, out.stderr);
  assert.equal(out.json.protected, true);
  assert.equal(out.json.range.from, mainCommit);
  assert.equal(out.json.range.to, head);
  assert.ok(out.json.protectedPaths.includes('.hk/x.pkl'));
  const targets = out.json.paths.map((p) => p.to);
  assert.ok(targets.includes('.hk/x.pkl'));
  assert.ok(targets.includes('later.txt'));
});

test('--range starting at @- is rejected', () => {
  const repo = initRepo();
  jj(repo, ['new', '-m', 'c1']);
  fs.writeFileSync(path.join(repo, 'a.txt'), 'a\n');
  jj(repo, ['new', '-m', 'c2']);
  fs.writeFileSync(path.join(repo, 'b.txt'), 'b\n');
  const parent = rev(repo, '@-', 'commit_id');
  const head = rev(repo, '@', 'commit_id');
  const out = classify(repo, ['--range', `${parent}..${head}`]);
  assert.equal(out.status, 2, out.stderr + out.stdout);
  assert.match(out.stderr, /range/i);
  assert.match(out.stderr, /[0-9a-f]{12}/);
});

function git(dir, args) {
  const result = spawnSync(
    'git',
    ['-c', 'user.email=a@b.c', '-c', 'user.name=t', ...args],
    { cwd: dir, encoding: 'utf8' },
  );
  assert.equal(result.status, 0, `git ${args.join(' ')}: ${result.stderr}`);
  return result;
}

function originCommit(origin, file, message) {
  fs.writeFileSync(path.join(origin, file), `${message}\n`);
  git(origin, ['add', file]);
  git(origin, ['commit', '-q', '-m', message]);
}

// A jj clone of a git origin whose main is tracked. Returns both directories.
function cloneRepo() {
  const origin = tempDir('vbr-origin-');
  git(origin, ['init', '-q', '-b', 'main']);
  originCommit(origin, 'README', 'origin base');
  const repo = tempDir();
  jj(origin, ['git', 'clone', '--quiet', origin, repo]);
  return { origin, repo };
}

// Land one change on local main only (never pushed); returns its commit.
function landLocally(repo, file) {
  jj(repo, ['new', 'main', '-m', `landed ${file}`]);
  fs.writeFileSync(path.join(repo, file), 'landed\n');
  jj(repo, ['bookmark', 'set', 'main', '-r', '@']);
  return rev(repo, 'main', 'commit_id');
}

function startWork(repo, file) {
  jj(repo, ['new', '-m', 'feature']);
  fs.writeFileSync(path.join(repo, file), 'feature\n');
}

test('trunk is local main even when it is one landed change ahead of main@origin', () => {
  const { repo } = cloneRepo();
  const originMain = rev(repo, 'main@origin', 'commit_id');
  const landed = landLocally(repo, 'landed.txt');
  assert.notEqual(landed, originMain);
  startWork(repo, 'feature.txt');
  const out = classify(repo);
  assert.equal(out.status, 0, out.stderr);
  assert.equal(out.json.policy.bookmark, 'main');
  assert.equal(out.json.policy.commit, landed);
  assert.equal(out.json.range.from, landed);
  const sides = out.json.paths.flatMap((p) => [p.from, p.to]);
  assert.equal(sides.includes('landed.txt'), false);
  assert.deepEqual(sides.filter(Boolean), ['feature.txt', 'feature.txt']);
});

test('local main diverged from a tracked main@origin (conflicted bookmark) exits 2', () => {
  const { origin, repo } = cloneRepo();
  landLocally(repo, 'local.txt');
  startWork(repo, 'feature.txt');
  originCommit(origin, 'origin-only.txt', 'origin only');
  jj(repo, ['git', 'fetch']);
  assert.equal(rev(repo, 'bookmarks(exact:"main")', 'commit_id').length, 80, 'main should be conflicted');
  const out = classify(repo);
  assert.equal(out.status, 2, out.stdout);
  assert.match(out.stderr, /trunk: local main is conflicted/);
  assert.equal(out.json, null);
});

test('local main moved independently of an untracked, moved main@origin exits 2', () => {
  const { origin, repo } = cloneRepo();
  jj(repo, ['bookmark', 'untrack', 'main@origin']);
  landLocally(repo, 'local.txt');
  startWork(repo, 'feature.txt');
  originCommit(origin, 'origin-only.txt', 'origin only');
  jj(repo, ['git', 'fetch']);
  assert.equal(rev(repo, 'bookmarks(exact:"main")', 'commit_id').length, 40);
  const out = classify(repo);
  assert.equal(out.status, 2, out.stdout);
  assert.match(out.stderr, /trunk: local main and main@origin have diverged/);
});

test('local main behind main@origin exits 2', () => {
  const { origin, repo } = cloneRepo();
  const base = rev(repo, 'main', 'commit_id');
  originCommit(origin, 'origin-only.txt', 'origin only');
  jj(repo, ['git', 'fetch']);
  jj(repo, ['bookmark', 'set', 'main', '-r', base, '--allow-backwards']);
  startWork(repo, 'feature.txt');
  const out = classify(repo);
  assert.equal(out.status, 2, out.stdout);
  assert.match(out.stderr, /trunk: local main is behind main@origin/);
});

test('local main equal to main@origin classifies normally', () => {
  const { repo } = cloneRepo();
  const base = rev(repo, 'main', 'commit_id');
  startWork(repo, 'feature.txt');
  const out = classify(repo);
  assert.equal(out.status, 0, out.stderr);
  assert.equal(out.json.range.from, base);
});

test('main moved past fork point: trunk-only files are not in paths', () => {
  const repo = initRepo();
  jj(repo, ['new', '-m', 'feature']);
  fs.writeFileSync(path.join(repo, 'feature.txt'), 'feature\n');
  const featureChange = rev(repo, '@', 'change_id');
  const fork = rev(repo, 'main', 'commit_id');
  jj(repo, ['new', 'main', '-m', 'trunk only']);
  fs.writeFileSync(path.join(repo, 'trunk-only.txt'), 'trunk\n');
  jj(repo, ['bookmark', 'set', 'main', '-r', '@']);
  const out = classify(repo, ['--head', featureChange]);
  assert.equal(out.status, 0, out.stderr);
  assert.equal(out.json.range.from, fork);
  const sides = out.json.paths.flatMap((p) => [p.from, p.to]);
  assert.equal(sides.includes('trunk-only.txt'), false);
  assert.ok(sides.includes('feature.txt'));
});

test('change edits risk.toml to downgrade; policy still comes from main', () => {
  const repo = initRepo();
  writeRisk(repo, 'version = 1\ndefault = "high"\n[[rule]]\npaths = ["src/**"]\ntier = "high"\n');
  jj(repo, ['describe', '-m', 'base with policy']);
  jj(repo, ['new', '-m', 'downgrade']);
  writeRisk(repo, 'version = 1\ndefault = "low"\n[[rule]]\npaths = ["src/**"]\ntier = "low"\n');
  fs.mkdirSync(path.join(repo, 'src'), { recursive: true });
  fs.writeFileSync(path.join(repo, 'src', 'app.js'), 'x\n');
  const mainCommit = rev(repo, 'main', 'commit_id');
  const out = classify(repo);
  assert.equal(out.status, 0, out.stderr);
  assert.equal(out.json.policy.commit, mainCommit);
  assert.equal(out.json.policy.riskToml, true);
  assert.equal(out.json.tier, 'high');
  assert.equal(out.json.paths.find((p) => p.to === 'src/app.js').tier, 'high');
  assert.equal(out.json.protected, true);
  assert.ok(out.json.protectedPaths.includes('.sjujperpowers/risk.toml'));
});

test('missing risk.toml classifies every path high', () => {
  const repo = initRepo();
  jj(repo, ['new', '-m', 'work']);
  fs.writeFileSync(path.join(repo, 'notes.txt'), 'n\n');
  const out = classify(repo);
  assert.equal(out.status, 0, out.stderr);
  assert.equal(out.json.policy.riskToml, false);
  assert.equal(out.json.tier, 'high');
  assert.equal(out.json.paths.find((p) => p.to === 'notes.txt').tier, 'high');
  assert.equal(out.json.protected, false);
});

test('malformed risk.toml fails closed: high plus policy.error, exit 0', () => {
  const repo = initRepo();
  writeRisk(repo, 'version = 2\ndefault = "low"\n');
  jj(repo, ['describe', '-m', 'bad policy']);
  jj(repo, ['new', '-m', 'work']);
  fs.writeFileSync(path.join(repo, 'notes.txt'), 'n\n');
  const out = classify(repo);
  assert.equal(out.status, 0, out.stderr);
  assert.equal(out.json.tier, 'high');
  assert.equal(out.json.policy.riskToml, true);
  assert.equal(typeof out.json.policy.error, 'string');
  assert.ok(out.json.policy.error.length > 0);
});

test('empty @ uses @-', () => {
  const repo = initRepo();
  jj(repo, ['new', '-m', 'work']);
  fs.writeFileSync(path.join(repo, 'work.txt'), 'w\n');
  const parentCommit = rev(repo, '@', 'commit_id');
  const parentChange = rev(repo, '@', 'change_id');
  jj(repo, ['new']);
  assert.equal(rev(repo, '@', 'empty'), 'true');
  const out = classify(repo);
  assert.equal(out.status, 0, out.stderr);
  assert.equal(out.json.head.commit, parentCommit);
  assert.equal(out.json.head.change, parentChange);
  assert.equal(out.json.range.to, parentCommit);
  assert.ok(out.json.paths.some((p) => p.to === 'work.txt'));
});

test('rename counts both sides', () => {
  const repo = initRepo();
  writeRisk(
    repo,
    'version = 1\ndefault = "low"\n[[rule]]\npaths = ["secret/**"]\ntier = "high"\n[[rule]]\npaths = ["public/**"]\ntier = "low"\n',
  );
  fs.mkdirSync(path.join(repo, 'secret'), { recursive: true });
  fs.writeFileSync(path.join(repo, 'secret', 'token.txt'), 't\n');
  jj(repo, ['describe', '-m', 'base with secret']);
  jj(repo, ['new', '-m', 'rename']);
  fs.mkdirSync(path.join(repo, 'public'), { recursive: true });
  fs.renameSync(path.join(repo, 'secret', 'token.txt'), path.join(repo, 'public', 'token.txt'));
  const out = classify(repo);
  assert.equal(out.status, 0, out.stderr);
  const row = out.json.paths.find((p) => p.status === 'renamed');
  assert.ok(row, JSON.stringify(out.json.paths));
  assert.equal(row.from, 'secret/token.txt');
  assert.equal(row.to, 'public/token.txt');
  assert.equal(row.tier, 'high');
  assert.equal(out.json.tier, 'high');
});

test('deletes are listed', () => {
  const repo = initRepo();
  fs.writeFileSync(path.join(repo, 'doomed.txt'), 'gone\n');
  jj(repo, ['describe', '-m', 'base with doomed']);
  jj(repo, ['new', '-m', 'delete']);
  fs.rmSync(path.join(repo, 'doomed.txt'));
  const out = classify(repo);
  assert.equal(out.status, 0, out.stderr);
  const row = out.json.paths.find((p) => p.from === 'doomed.txt');
  assert.ok(row);
  assert.equal(row.status, 'removed');
});

test('paths with spaces and newlines round-trip', () => {
  const repo = initRepo();
  jj(repo, ['new', '-m', 'odd names']);
  fs.writeFileSync(path.join(repo, 'file with spaces.txt'), 's\n');
  fs.writeFileSync(path.join(repo, 'weird\nname.txt'), 'n\n');
  const out = classify(repo);
  assert.equal(out.status, 0, out.stderr);
  const targets = out.json.paths.map((p) => p.to);
  assert.ok(targets.includes('file with spaces.txt'));
  assert.ok(targets.includes('weird\nname.txt'));
});

test('--raise only raises', () => {
  const repo = initRepo();
  writeRisk(repo, 'version = 1\ndefault = "low"\n');
  jj(repo, ['describe', '-m', 'policy']);
  jj(repo, ['new', '-m', 'work']);
  fs.writeFileSync(path.join(repo, 'notes.txt'), 'n\n');
  const raised = classify(repo, ['--raise', 'medium']);
  assert.equal(raised.status, 0, raised.stderr);
  assert.equal(raised.json.computedTier, 'low');
  assert.equal(raised.json.tier, 'medium');
  const lowered = classify(repo, ['--raise', 'low']);
  assert.equal(lowered.status, 0, lowered.stderr);
  assert.equal(lowered.json.computedTier, 'low');
  assert.equal(lowered.json.tier, 'low');
});

test('first matching rule wins', () => {
  const repo = initRepo();
  writeRisk(
    repo,
    'version = 1\ndefault = "low"\n[[rule]]\npaths = ["src/**"]\ntier = "medium"\n[[rule]]\npaths = ["src/special.js"]\ntier = "high"\n',
  );
  jj(repo, ['describe', '-m', 'policy']);
  jj(repo, ['new', '-m', 'work']);
  fs.mkdirSync(path.join(repo, 'src'), { recursive: true });
  fs.writeFileSync(path.join(repo, 'src', 'special.js'), 's\n');
  fs.writeFileSync(path.join(repo, 'other.txt'), 'o\n');
  const out = classify(repo);
  assert.equal(out.status, 0, out.stderr);
  assert.equal(out.json.paths.find((p) => p.to === 'src/special.js').tier, 'medium');
  assert.equal(out.json.paths.find((p) => p.to === 'other.txt').tier, 'low');
  assert.equal(out.json.tier, 'medium');
});

test('nothing pending exits 2', () => {
  const repo = initRepo();
  jj(repo, ['new']);
  const out = classify(repo);
  assert.equal(out.status, 2);
  assert.match(out.stderr, /nothing pending/);
});

test('missing main bookmark exits 2', () => {
  const repo = initRepo();
  jj(repo, ['bookmark', 'delete', 'main']);
  jj(repo, ['new', '-m', 'work']);
  fs.writeFileSync(path.join(repo, 'a.txt'), 'a\n');
  const out = classify(repo);
  assert.equal(out.status, 2);
  assert.match(out.stderr, /no trunk/);
});

test('matching --range is accepted', () => {
  const repo = initRepo();
  const mainCommit = rev(repo, 'main', 'commit_id');
  jj(repo, ['new', '-m', 'work']);
  fs.writeFileSync(path.join(repo, 'a.txt'), 'a\n');
  const head = rev(repo, '@', 'commit_id');
  const out = classify(repo, ['--range', `${mainCommit}..${head}`]);
  assert.equal(out.status, 0, out.stderr);
  assert.equal(out.json.range.from, mainCommit);
  assert.equal(out.json.range.to, head);
});

test('protected globs from risk.toml are honored', () => {
  const repo = initRepo();
  writeRisk(repo, 'version = 1\ndefault = "low"\nprotected = ["secrets/**"]\n');
  jj(repo, ['describe', '-m', 'policy']);
  jj(repo, ['new', '-m', 'work']);
  fs.mkdirSync(path.join(repo, 'secrets'), { recursive: true });
  fs.writeFileSync(path.join(repo, 'secrets', 'key.txt'), 'k\n');
  const out = classify(repo);
  assert.equal(out.status, 0, out.stderr);
  assert.equal(out.json.protected, true);
  assert.ok(out.json.protectedPaths.includes('secrets/key.txt'));
  assert.equal(out.json.paths.find((p) => p.to === 'secrets/key.txt').protected, true);
  assert.equal(out.json.tier, 'low');
});

test('built-in protected paths are reported by classification', () => {
  const repo = initRepo();
  writeRisk(repo, 'version = 1\ndefault = "low"\n');
  jj(repo, ['describe', '-m', 'policy']);
  jj(repo, ['new', '-m', 'work']);
  const files = [
    'devenv.nix',
    '.agents/skills/verify-x/SKILL.md',
    '.agents/skills/verify-x/features/a.md',
  ];
  for (const file of files) {
    fs.mkdirSync(path.dirname(path.join(repo, file)), { recursive: true });
    fs.writeFileSync(path.join(repo, file), 'x\n');
  }
  fs.writeFileSync(path.join(repo, 'plain.txt'), 'p\n');
  const out = classify(repo);
  assert.equal(out.status, 0, out.stderr);
  assert.equal(out.json.protected, true);
  assert.deepEqual(out.json.protectedPaths, [...files].sort());
  assert.equal(out.json.paths.find((p) => p.to === 'plain.txt').protected, false);
  assert.equal(out.json.tier, 'low');
});

test('testCommand comes from risk.toml on trunk; absent is null', () => {
  const repo = initRepo();
  writeRisk(repo, 'version = 1\ndefault = "low"\n');
  jj(repo, ['describe', '-m', 'policy']);
  jj(repo, ['new', '-m', 'work']);
  fs.writeFileSync(path.join(repo, 'a.txt'), 'a\n');
  assert.equal(classify(repo).json.testCommand, null);

  const withTest = initRepo();
  writeRisk(withTest, 'version = 1\ndefault = "low"\ntest = "node --test tests/"\n');
  jj(withTest, ['describe', '-m', 'policy']);
  jj(withTest, ['new', '-m', 'work']);
  fs.writeFileSync(path.join(withTest, 'a.txt'), 'a\n');
  const out = classify(withTest);
  assert.equal(out.status, 0, out.stderr);
  assert.equal(out.json.testCommand, 'node --test tests/');
  assert.equal(out.json.policy.bookmark, 'main');
});

test('a stack that edits the test command still reports the one on trunk', () => {
  const repo = initRepo();
  writeRisk(repo, 'version = 1\ndefault = "low"\ntest = "node --test tests/"\n');
  jj(repo, ['describe', '-m', 'policy']);
  jj(repo, ['new', '-m', 'swap test']);
  writeRisk(repo, 'version = 1\ndefault = "low"\ntest = "true"\n');
  const out = classify(repo);
  assert.equal(out.status, 0, out.stderr);
  assert.equal(out.json.testCommand, 'node --test tests/');
  assert.equal(out.json.protected, true);
  assert.ok(out.json.protectedPaths.includes('.sjujperpowers/risk.toml'));
});

test('invalid test command in risk.toml fails closed with no testCommand', () => {
  const repo = initRepo();
  writeRisk(repo, 'version = 1\ndefault = "low"\ntest = ""\n');
  jj(repo, ['describe', '-m', 'bad policy']);
  jj(repo, ['new', '-m', 'work']);
  fs.writeFileSync(path.join(repo, 'a.txt'), 'a\n');
  const out = classify(repo);
  assert.equal(out.status, 0, out.stderr);
  assert.equal(out.json.tier, 'high');
  assert.equal(out.json.testCommand, null);
  assert.match(out.json.policy.error, /test/);
});
```

Extend Task 1's trunk boundary test so the classified range is checked against the same boundary:

Apply this change to `tests/starting-a-change/test-fresh-change.sh`:

```diff
--- a/tests/starting-a-change/test-fresh-change.sh
+++ b/tests/starting-a-change/test-fresh-change.sh
@@ -153,8 +153,8 @@
 assert_eq "$(cd "$fw/repo" && jj log -r "${tr_out%% *}" --no-graph -T 'description.first_line()')" "fork change" "trunk-rev revset resolves to the fork's head"
 
 # Case 7: local main is one landed change ahead of main@origin (landed, not pushed).
-# The stack finishing shows and the discard target start at local main, so the
-# landed change is in neither. A diverged or behind main stops.
+# The stack finishing shows, the discard target, and the classified range all start
+# at local main, so the landed change is in none of them. A diverged main stops.
 la="$TEST_ROOT/landed-ahead"; mkdir -p "$la/repo"; git init -q --bare "$la/origin.git"
 (cd "$la/repo" && jj git init >/dev/null 2>&1 && echo a > f && jj commit -m base >/dev/null 2>&1 \
   && jj bookmark create main -r @- >/dev/null 2>&1 && jj git remote add origin "$la/origin.git" \
@@ -168,6 +168,9 @@
 assert_eq "$stack" "stack change" "shown stack excludes the landed change"
 discard="$(cd "$la/repo" && jj log -r "$TRUNK..@" --no-graph -T 'description.first_line() ++ "|"')"
 [[ "$discard" != *"landed change"* ]] && pass "discard target excludes the landed change" || fail "discard target includes landed change: $discard"
+cls="$(node "$REPO_ROOT/skills/verifying-by-risk/scripts/classify-risk.mjs" --repo "$la/repo")"
+cls_paths="$(node -e 'const c=JSON.parse(process.argv[1]); console.log(c.paths.map(p=>p.to).join(","))' "$cls")"
+assert_eq "$cls_paths" "work.txt" "classified range matches the shown stack"
 git clone -q "$la/origin.git" "$la/other"
 (cd "$la/other" && echo other > other.txt && git add other.txt \
   && git -c user.name=t -c user.email=t@t commit -qm "other landing" && git push -q origin HEAD:main)
@@ -175,6 +178,8 @@
 set +e; tr_err="$(cd "$la/repo" && "$TRUNK_REV" 2>&1 >/dev/null)"; tr_code=$?; set -e
 assert_eq "$tr_code" "1" "diverged main (conflicted after fetch) stops trunk-rev"
 [[ "$tr_err" == *"conflicted"* ]] && pass "diverged message names the conflict" || fail "unexpected message: $tr_err"
+set +e; (node "$REPO_ROOT/skills/verifying-by-risk/scripts/classify-risk.mjs" --repo "$la/repo" >/dev/null 2>&1); cls_code=$?; set -e
+assert_eq "$cls_code" "2" "diverged main stops classification too"
 (cd "$la/repo" && jj bookmark set main -r 'main@origin-' --allow-backwards >/dev/null 2>&1)
 set +e; tr_err="$(cd "$la/repo" && "$TRUNK_REV" 2>&1 >/dev/null)"; tr_code=$?; set -e
 assert_eq "$tr_code" "1" "local main behind origin stops trunk-rev"
```

- [ ] **Step 2: Run it to verify it fails**

Run: `node --test tests/verifying-by-risk/test-classify-risk.mjs`
Expected: FAIL; every test reports a non-zero status because `classify-risk.mjs` does not exist, and `bash tests/starting-a-change/test-fresh-change.sh` exits non-zero when it reaches Case 7's classification (module not found).

- [ ] **Step 3: Implement the script**

Create `skills/verifying-by-risk/scripts/classify.mjs`:

```js
import {
  TIERS,
  fail,
  jj,
  resolveHead,
  resolveTrunk,
  resolveCommit,
  forkPoint,
  changedPaths,
  maxTier,
} from './jj.mjs';
import { parseRiskToml, classifyPaths } from './policy.mjs';

// Classify every pending change from the local trunk to head against the
// policy committed on trunk. The range, trunk, and policy are never inputs.
export function classify(repo, { head: headArg, range: rangeArg, raise } = {}) {
  if (raise !== undefined && !TIERS.includes(raise)) fail('--raise must be low, medium, or high');
  const head = resolveHead(repo, headArg);
  const trunk = resolveTrunk(repo);
  const from = forkPoint(repo, trunk.commit, head.commit);
  if (from === head.commit) fail('nothing pending');

  if (rangeArg !== undefined) {
    const parts = rangeArg.split('..');
    if (parts.length !== 2 || !parts[0] || !parts[1]) fail('--range must be FROM..TO');
    const givenFrom = resolveCommit(repo, parts[0]);
    const givenTo = resolveCommit(repo, parts[1]);
    if (!givenFrom || !givenTo) fail(`cannot resolve --range ${rangeArg}`);
    if (givenFrom !== from || givenTo !== head.commit) {
      fail(`--range ${givenFrom}..${givenTo} does not match computed range ${from}..${head.commit}`);
    }
  }

  const rows = changedPaths(repo, from, head.commit);
  const shown = jj(
    repo,
    ['file', 'show', '-r', trunk.commit, 'root:".sjujperpowers/risk.toml"'],
    { allowFail: true },
  );
  const policy = { bookmark: trunk.bookmark, commit: trunk.commit, riskToml: shown.status === 0 };
  let parsed = null;
  if (shown.status === 0) {
    try {
      parsed = parseRiskToml(shown.stdout);
    } catch (error) {
      policy.error = error.message;
    }
  }
  const classified = classifyPaths(rows, parsed);
  return {
    head,
    range: { from, to: head.commit },
    policy,
    testCommand: parsed?.testCommand ?? null,
    tier: raise ? maxTier(classified.computedTier, raise) : classified.computedTier,
    computedTier: classified.computedTier,
    protected: classified.protected,
    protectedPaths: classified.protectedPaths,
    paths: classified.paths,
  };
}
```

Create `skills/verifying-by-risk/scripts/classify-risk.mjs` (executable):

```js
#!/usr/bin/env node
import { flag, repoArg, snapshot } from './jj.mjs';
import { classify } from './classify.mjs';

const argv = process.argv.slice(2);
const repo = repoArg(argv);
snapshot(repo);
const result = classify(repo, {
  head: flag(argv, '--head'),
  range: flag(argv, '--range'),
  raise: flag(argv, '--raise'),
});
process.stdout.write(`${JSON.stringify(result)}\n`);
```

Run: `chmod +x skills/verifying-by-risk/scripts/classify-risk.mjs`

- [ ] **Step 4: Run it to verify it passes**

Run: `node --test tests/verifying-by-risk/test-classify-risk.mjs && bash tests/starting-a-change/test-fresh-change.sh`
Expected: `STATUS: PASSED` with 62 `[PASS]` lines from the shell test, and PASS, 25 tests, covering every case the spec lists under Classification: the multi-change stack where only an earlier change is protected, rejection of a range starting at `@-`, local `main` one landed change ahead of `main@origin` (accepted) and behind, diverged, or conflicted (exit 2), policy and `test` from trunk when the change edits `risk.toml`, missing `risk.toml` → `high`, the built-in protected paths, empty `@`, renames, deletes, and paths with spaces and newlines.

- [ ] **Step 5: Commit**

```bash
jj commit skills/verifying-by-risk/scripts/classify.mjs skills/verifying-by-risk/scripts/classify-risk.mjs tests/verifying-by-risk/test-classify-risk.mjs tests/starting-a-change/test-fresh-change.sh -m "Classify the whole pending stack against policy on trunk"
```

### Task 4: Verdict ledger

**Files:**
- Create: `skills/verifying-by-risk/scripts/verdict.mjs` (executable)
- Test: `tests/verifying-by-risk/test-verdict.mjs`

**Interfaces:**
- Consumes: Task 2 `jj.mjs`; Task 3 `classify.mjs`.
- Produces:
  - `verdict.mjs append [--raise TIER] --grade <GRADES> --implementer-family F [--verifier-family F] [--run '{"command":…,"exit":N,"evidence":…}']...` reclassifies and appends one row `{ change, commit, range, policyCommit, testCommand, tier, computedTier, protected, protectedPaths, grade, runs, implementerFamily, verifierFamily, timestamp }`. Exit 2 for `--classification`, an unknown grade, `high` graded above `blocked` without a different verifier family, or a grade of `unit-tested` or above without a passing run of the declared `testCommand` (spec D14 adds `--code-reviewer`, `codeReviewers`/`verifySkill` row fields, the no-verify-skill high-tier exception, the no-declared-test setup gap, and the `type-check-only` refusal for a missing declared receipt while a verify skill exists).
  - `verdict.mjs check [--head REV]` reclassifies and prints `{ status: current|void|missing, reasons, row }`; exit 0 only when `current`. Void also covers a stored tier below the recomputed tier and any `protected`/`protectedPaths` mismatch.
  - `verdict.mjs summary [--head REV]` prints at most 12 lines for the brief's Verification section.

- [ ] **Step 1: Write the failing test**

Create `tests/verifying-by-risk/test-verdict.mjs`:

```js
import { test, after } from 'node:test';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

process.env.JJ_USER = 'vbr-test';
process.env.JJ_EMAIL = 'vbr-test@example.com';

const VERDICT = path.join(
  path.dirname(fileURLToPath(import.meta.url)),
  '../../skills/verifying-by-risk/scripts/verdict.mjs',
);
const TEST_COMMAND = 'node --test tests/';

// Every temp dir this file creates, removed once the file's tests finish.
const tempDirs = [];
after(() => {
  for (const dir of tempDirs) fs.rmSync(dir, { recursive: true, force: true });
});

function jj(repo, args) {
  const result = spawnSync('jj', args, { cwd: repo, encoding: 'utf8' });
  if (result.status !== 0) {
    throw new Error(
      `jj ${args.join(' ')} failed (${result.status}): ${result.stderr || result.stdout}`,
    );
  }
  return result;
}

function rev(repo, revset, template) {
  return jj(repo, ['log', '-r', revset, '--no-graph', '-T', template]).stdout.trim();
}

function write(repo, file, body = 'x\n') {
  const full = path.join(repo, file);
  fs.mkdirSync(path.dirname(full), { recursive: true });
  fs.writeFileSync(full, body);
}

// A repo whose main has no risk.toml (every path classifies high).
function initRepo({ risk } = {}) {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'vbr-'));
  tempDirs.push(dir);
  jj(dir, ['git', 'init', '--quiet', dir]);
  write(dir, 'README', 'base\n');
  if (risk !== undefined) write(dir, '.sjujperpowers/risk.toml', risk);
  jj(dir, ['describe', '-m', 'base']);
  jj(dir, ['bookmark', 'create', 'main', '-r', '@']);
  return dir;
}

function policy({ tier = 'low', test = TEST_COMMAND } = {}) {
  return `version = 1\ndefault = "${tier}"\n${test ? `test = "${test}"\n` : ''}`;
}

// main declares a policy; a child change adds a.txt.
function workRepo(options) {
  const repo = initRepo({ risk: policy(options) });
  jj(repo, ['new', '-m', 'work']);
  write(repo, 'a.txt', 'a\n');
  return repo;
}

function run(repo, args) {
  return spawnSync(process.execPath, [VERDICT, '--repo', repo, ...args], { encoding: 'utf8' });
}

const receipt = (command = TEST_COMMAND, exit = 0) =>
  JSON.stringify({ command, exit, evidence: 'ok' });

function append(repo, { grade = 'blocked', implementer = 'grok', verifier, runs = [], extra = [] } = {}) {
  const args = ['append', '--grade', grade, '--implementer-family', implementer];
  if (verifier) args.push('--verifier-family', verifier);
  for (const item of runs) args.push('--run', item);
  return run(repo, [...args, ...extra]);
}

const ledgerPath = (repo) => path.join(repo, '.sjujperpowers', 'verdicts.jsonl');

function readRows(repo) {
  return fs
    .readFileSync(ledgerPath(repo), 'utf8')
    .split('\n')
    .filter(Boolean)
    .map((line) => JSON.parse(line));
}

function tamperLastRow(repo, edit) {
  const rows = readRows(repo);
  edit(rows[rows.length - 1]);
  fs.writeFileSync(ledgerPath(repo), `${rows.map((row) => JSON.stringify(row)).join('\n')}\n`);
}

function check(repo, args = []) {
  const result = run(repo, ['check', ...args]);
  return { status: result.status, json: JSON.parse(result.stdout), stderr: result.stderr };
}

test('append no longer accepts --classification', () => {
  const repo = workRepo();
  const result = append(repo, { extra: ['--classification', '/tmp/does-not-matter.json'] });
  assert.equal(result.status, 2, result.stdout);
  assert.match(result.stderr, /--classification/);
  assert.equal(fs.existsSync(ledgerPath(repo)), false);
});

test('high tier needs a different-family verifier unless failed or blocked', () => {
  const repo = workRepo({ tier: 'high' });
  const same = append(repo, {
    grade: 'unit-tested',
    verifier: 'grok',
    runs: [receipt()],
  });
  assert.equal(same.status, 2, same.stderr);
  assert.match(same.stderr, /different-family/);
  const none = append(repo, { grade: 'live-verified', runs: [receipt()] });
  assert.equal(none.status, 2);
  assert.match(none.stderr, /different-family/);
  assert.equal(fs.existsSync(ledgerPath(repo)), false);
  assert.equal(append(repo, { grade: 'blocked' }).status, 0);
  assert.equal(append(repo, { grade: 'failed' }).status, 0);
  const different = append(repo, { grade: 'unit-tested', verifier: 'claude', runs: [receipt()] });
  assert.equal(different.status, 0, different.stderr);
});

test('a repo with no risk.toml classifies high, so append needs a different family', () => {
  const repo = initRepo();
  jj(repo, ['new', '-m', 'work']);
  write(repo, 'a.txt', 'a\n');
  const result = append(repo, { grade: 'type-check-only' });
  assert.equal(result.status, 2);
  assert.match(result.stderr, /different-family/);
  assert.equal(append(repo, { grade: 'type-check-only', verifier: 'claude' }).status, 0);
});

test('append creates a self-ignoring gitignore and verdicts stay untracked', () => {
  const repo = workRepo();
  const appended = append(repo);
  assert.equal(appended.status, 0, appended.stderr);
  const ignore = fs.readFileSync(path.join(repo, '.sjujperpowers', '.gitignore'), 'utf8');
  assert.equal(ignore, '/.gitignore\n/verdicts.jsonl\n');
  assert.ok(fs.existsSync(ledgerPath(repo)));
  jj(repo, ['status']);
  const listed = jj(repo, ['file', 'list']).stdout;
  assert.equal(listed.includes('verdicts.jsonl'), false, listed);
  assert.equal(listed.includes('.gitignore'), false, listed);
  assert.ok(listed.includes('a.txt'));
});

test('existing gitignore lacking the verdicts entry exits 2 and is not modified', () => {
  const repo = workRepo();
  const dir = path.join(repo, '.sjujperpowers');
  const prior = '# keep\n';
  fs.writeFileSync(path.join(dir, '.gitignore'), prior);
  const appended = append(repo);
  assert.equal(appended.status, 2);
  assert.match(appended.stderr, /verdicts\.jsonl/);
  assert.equal(fs.readFileSync(path.join(dir, '.gitignore'), 'utf8'), prior);
  assert.equal(fs.existsSync(ledgerPath(repo)), false);
});

test('append rejects an unknown grade', () => {
  const repo = workRepo();
  const bad = append(repo, { grade: 'looks-fine', runs: [receipt()] });
  assert.equal(bad.status, 2);
  assert.equal(fs.existsSync(ledgerPath(repo)), false);
});

test('check is current, void after describe, void after main moves, missing otherwise', () => {
  const repo = workRepo();
  const missing = run(repo, ['check']);
  assert.equal(missing.status, 1);
  assert.equal(JSON.parse(missing.stdout).status, 'missing');

  const appended = append(repo, { verifier: 'claude', runs: [receipt()] });
  assert.equal(appended.status, 0, appended.stderr);
  const current = check(repo);
  assert.equal(current.status, 0, JSON.stringify(current.json));
  assert.equal(current.json.status, 'current');
  assert.equal(current.json.row.grade, 'blocked');
  assert.equal(current.json.row.verifierFamily, 'claude');
  assert.equal(current.json.row.implementerFamily, 'grok');

  const summary = run(repo, ['summary']);
  assert.equal(summary.status, 0, summary.stderr);
  assert.ok(summary.stdout.trim().split('\n').length <= 12, summary.stdout);
  assert.match(summary.stdout, /current/);
  assert.match(summary.stdout, /blocked/);
  assert.match(summary.stdout, /^Self-reported:/m);

  jj(repo, ['describe', '-m', 'work rewritten']);
  const rewritten = check(repo);
  assert.equal(rewritten.status, 1);
  assert.equal(rewritten.json.status, 'void');
  assert.ok(rewritten.json.reasons.length > 0);

  const repo2 = workRepo();
  const change = rev(repo2, '@', 'change_id');
  assert.equal(append(repo2, { grade: 'failed' }).status, 0);
  jj(repo2, ['new', 'main', '-m', 'trunk moves']);
  write(repo2, 'trunk.txt', 't\n');
  jj(repo2, ['bookmark', 'set', 'main', '-r', '@']);
  const moved = check(repo2, ['--head', change]);
  assert.equal(moved.status, 1, JSON.stringify(moved.json));
  assert.equal(moved.json.status, 'void');
  assert.ok(moved.json.reasons.some((reason) => /policyCommit|range|trunk/i.test(reason)));
});

test('low tier with a declared test command appends and records the policy', () => {
  const repo = workRepo();
  const appended = append(repo, { grade: 'unit-tested', runs: [receipt()] });
  assert.equal(appended.status, 0, appended.stderr);
  const [row] = readRows(repo);
  assert.equal(row.verifierFamily, null);
  assert.equal(row.tier, 'low');
  assert.equal(row.computedTier, 'low');
  assert.equal(row.testCommand, TEST_COMMAND);
  assert.equal(row.protected, false);
  assert.deepEqual(row.protectedPaths, []);
  assert.equal(row.policyCommit, rev(repo, 'main', 'commit_id'));
  assert.equal(row.range.from, rev(repo, 'main', 'commit_id'));
  assert.equal(row.range.to, row.commit);
  assert.deepEqual(row.runs, [{ command: TEST_COMMAND, exit: 0, evidence: 'ok' }]);
  assert.equal(check(repo).status, 0);
});

test('unit-tested and above fail when risk.toml on main declares no test command', () => {
  const repo = workRepo({ test: '' });
  for (const grade of ['unit-tested', 'behavior-tested', 'live-verified']) {
    const result = append(repo, { grade, runs: [receipt()] });
    assert.equal(result.status, 2, `${grade}: ${result.stdout}`);
    assert.match(result.stderr, /no test command/);
  }
  assert.equal(fs.existsSync(ledgerPath(repo)), false);
  const typeCheck = append(repo, { grade: 'type-check-only' });
  assert.equal(typeCheck.status, 0, typeCheck.stderr);
  assert.equal(readRows(repo)[0].testCommand, null);
});

test('a risk.toml-less repo cannot reach unit-tested either', () => {
  const repo = initRepo();
  jj(repo, ['new', '-m', 'work']);
  write(repo, 'a.txt', 'a\n');
  const result = append(repo, { grade: 'unit-tested', verifier: 'claude', runs: [receipt('true')] });
  assert.equal(result.status, 2);
  assert.match(result.stderr, /no test command/);
});

test('unit-tested needs a passing run of the exact declared command', () => {
  const repo = workRepo();
  for (const [label, runs, pattern] of [
    ['no runs', [], new RegExp(TEST_COMMAND)],
    ['substituted command', [receipt('true')], new RegExp(TEST_COMMAND)],
    ['declared command with extra args', [receipt(`${TEST_COMMAND} --only-fast`)], new RegExp(TEST_COMMAND)],
    ['declared command that failed', [receipt(TEST_COMMAND, 1)], new RegExp(TEST_COMMAND)],
    ['passing substitute next to failing real run', [receipt('true'), receipt(TEST_COMMAND, 1)], new RegExp(TEST_COMMAND)],
  ]) {
    const result = append(repo, { grade: 'unit-tested', runs });
    assert.equal(result.status, 2, `${label}: ${result.stdout}`);
    assert.match(result.stderr, pattern, label);
  }
  assert.equal(fs.existsSync(ledgerPath(repo)), false);

  const ok = append(repo, {
    grade: 'behavior-tested',
    runs: [receipt('true'), receipt(TEST_COMMAND, 1), receipt(TEST_COMMAND, 0)],
  });
  assert.equal(ok.status, 0, ok.stderr);
  assert.equal(readRows(repo).length, 1);
});

test('a stack that edits risk.toml test still has to run the command declared on main', () => {
  const repo = workRepo();
  write(repo, '.sjujperpowers/risk.toml', policy({ test: 'true' }));
  const substituted = append(repo, { grade: 'unit-tested', verifier: 'claude', runs: [receipt('true')] });
  assert.equal(substituted.status, 2, substituted.stdout);
  assert.match(substituted.stderr, new RegExp(TEST_COMMAND));
  const declared = append(repo, { grade: 'unit-tested', verifier: 'claude', runs: [receipt()] });
  assert.equal(declared.status, 0, declared.stderr);
  const [row] = readRows(repo);
  assert.equal(row.testCommand, TEST_COMMAND);
  assert.equal(row.protected, true);
  assert.ok(row.protectedPaths.includes('.sjujperpowers/risk.toml'));
});

test('--raise high on a low stack is recorded, needs a verifier, and stays current', () => {
  const repo = workRepo();
  const same = append(repo, { grade: 'unit-tested', runs: [receipt()], extra: ['--raise', 'high'] });
  assert.equal(same.status, 2);
  assert.match(same.stderr, /different-family/);
  assert.equal(fs.existsSync(ledgerPath(repo)), false);

  const raised = append(repo, {
    grade: 'unit-tested',
    verifier: 'claude',
    runs: [receipt()],
    extra: ['--raise', 'high'],
  });
  assert.equal(raised.status, 0, raised.stderr);
  const [row] = readRows(repo);
  assert.equal(row.tier, 'high');
  assert.equal(row.computedTier, 'low');
  const current = check(repo);
  assert.equal(current.status, 0, JSON.stringify(current.json));
  assert.equal(current.json.status, 'current');
  const summary = run(repo, ['summary']);
  assert.match(summary.stdout, /Tier: high \(raised from low\)/);
});

test('--raise cannot lower the computed tier', () => {
  const repo = workRepo({ tier: 'high' });
  const result = append(repo, { verifier: 'claude', extra: ['--raise', 'low'] });
  assert.equal(result.status, 0, result.stderr);
  assert.equal(readRows(repo)[0].tier, 'high');
});

test('tampering the stored tier from high to low voids the verdict', () => {
  const repo = workRepo({ tier: 'high' });
  const appended = append(repo, { verifier: 'claude' });
  assert.equal(appended.status, 0, appended.stderr);
  assert.equal(check(repo).status, 0);
  tamperLastRow(repo, (row) => {
    assert.equal(row.tier, 'high');
    row.tier = 'low';
    row.computedTier = 'low';
  });
  const voided = check(repo);
  assert.equal(voided.status, 1);
  assert.equal(voided.json.status, 'void');
  assert.deepEqual(voided.json.reasons.length, 1, JSON.stringify(voided.json.reasons));
  assert.match(voided.json.reasons[0], /tier low is below the recomputed tier high/);
});

test('tampering protected from true to false voids the verdict', () => {
  const repo = workRepo();
  write(repo, 'devenv.nix', '{}\n');
  assert.equal(append(repo).status, 0);
  assert.equal(check(repo).status, 0);
  tamperLastRow(repo, (row) => {
    assert.equal(row.protected, true);
    row.protected = false;
  });
  const voided = check(repo);
  assert.equal(voided.status, 1);
  assert.equal(voided.json.status, 'void');
  assert.equal(voided.json.reasons.length, 1, JSON.stringify(voided.json.reasons));
  assert.match(voided.json.reasons[0], /protected does not match/);
});

test('tampering protectedPaths by dropping one voids the verdict', () => {
  const repo = workRepo();
  write(repo, 'devenv.nix', '{}\n');
  write(repo, '.agents/skills/verify-x/SKILL.md', 'skill\n');
  assert.equal(append(repo).status, 0);
  assert.equal(check(repo).status, 0);
  tamperLastRow(repo, (row) => {
    assert.deepEqual(row.protectedPaths, ['.agents/skills/verify-x/SKILL.md', 'devenv.nix']);
    row.protectedPaths = ['devenv.nix'];
  });
  const voided = check(repo);
  assert.equal(voided.status, 1);
  assert.equal(voided.json.status, 'void');
  assert.equal(voided.json.reasons.length, 1, JSON.stringify(voided.json.reasons));
  assert.match(voided.json.reasons[0], /protectedPaths do not match/);
});

test('a verdict recorded before a protected path was added is void after it is', () => {
  const repo = workRepo();
  assert.equal(append(repo).status, 0);
  assert.equal(check(repo).json.status, 'current');
  write(repo, 'devenv.nix', '{}\n');
  const voided = check(repo);
  assert.equal(voided.status, 1);
  assert.equal(voided.json.status, 'void');
  assert.ok(voided.json.reasons.some((reason) => /protected/.test(reason)));
});
```

- [ ] **Step 2: Run it to verify it fails**

Run: `node --test tests/verifying-by-risk/test-verdict.mjs`
Expected: FAIL; `verdict.mjs` does not exist

- [ ] **Step 3: Implement the script**

Create `skills/verifying-by-risk/scripts/verdict.mjs` (executable):

```js
#!/usr/bin/env node
import fs from 'node:fs';
import path from 'node:path';
import {
  GRADES,
  TIERS,
  fail,
  flag,
  flags,
  repoArg,
  snapshot,
  root,
} from './jj.mjs';
import { classify } from './classify.mjs';

const argv = process.argv.slice(2);
const repo = repoArg(argv);
const valued = new Set([
  '--repo',
  '--raise',
  '--grade',
  '--implementer-family',
  '--verifier-family',
  '--run',
  '--head',
]);
let command;
for (let i = 0; i < argv.length; i += 1) {
  if (valued.has(argv[i])) {
    i += 1;
    continue;
  }
  if (!argv[i].startsWith('--')) {
    command = argv[i];
    break;
  }
}
if (!['append', 'check', 'summary'].includes(command))
  fail('usage: verdict.mjs append|check|summary');
snapshot(repo);
const workspace = root(repo);
const ledgerDir = path.join(workspace, '.sjujperpowers');
const ledger = path.join(ledgerDir, 'verdicts.jsonl');
const ignorePath = path.join(ledgerDir, '.gitignore');
const IGNORE = '/.gitignore\n/verdicts.jsonl\n';

function readRows() {
  if (!fs.existsSync(ledger)) return [];
  return fs
    .readFileSync(ledger, 'utf8')
    .split('\n')
    .filter(Boolean)
    .map((line, index) => {
      try {
        return JSON.parse(line);
      } catch {
        fail(`malformed verdicts.jsonl line ${index + 1}`);
      }
    });
}

function latestFor(change) {
  const rows = readRows().filter((row) => row.change === change);
  return rows.length ? rows[rows.length - 1] : null;
}

function ensureIgnored() {
  if (!fs.existsSync(ignorePath)) {
    fs.mkdirSync(ledgerDir, { recursive: true });
    fs.writeFileSync(ignorePath, IGNORE);
    return;
  }
  const text = fs.readFileSync(ignorePath, 'utf8');
  const lines = text.split(/\r?\n/);
  const covered = lines.some(
    (line) => line.trim() === '/verdicts.jsonl' || line.trim() === 'verdicts.jsonl',
  );
  if (!covered) {
    fail('add /verdicts.jsonl to .sjujperpowers/.gitignore before appending a verdict');
  }
}

function append() {
  if (argv.includes('--classification'))
    fail('append classifies the stack itself; it does not take --classification');
  const grade = flag(argv, '--grade');
  const implementer = flag(argv, '--implementer-family');
  const verifier = flag(argv, '--verifier-family') ?? null;
  if (!GRADES.includes(grade)) fail(`grade must be one of ${GRADES.join(', ')}`);
  if (!implementer) fail('append requires --implementer-family');
  const runs = flags(argv, '--run').map((raw) => {
    let parsed;
    try {
      parsed = JSON.parse(raw);
    } catch {
      fail('--run must be JSON');
    }
    if (typeof parsed.command !== 'string' || typeof parsed.exit !== 'number') {
      fail('--run needs command and exit');
    }
    const run = { command: parsed.command, exit: parsed.exit };
    if (parsed.evidence !== undefined) run.evidence = parsed.evidence;
    return run;
  });
  const current = classify(repo, { head: flag(argv, '--head'), raise: flag(argv, '--raise') });
  if (
    current.tier === 'high' &&
    grade !== 'failed' &&
    grade !== 'blocked' &&
    (!verifier || verifier === implementer)
  ) {
    fail('high tier needs a different-family verifier');
  }
  // The test command comes from risk.toml on trunk, never from the agent.
  if (GRADES.indexOf(grade) >= GRADES.indexOf('unit-tested')) {
    if (!current.testCommand) fail('risk.toml on trunk declares no test command; grade stops at type-check-only');
    if (!runs.some((run) => run.command === current.testCommand && run.exit === 0)) {
      fail(`grade ${grade} needs a passing run of the declared test command: ${current.testCommand}`);
    }
  }
  ensureIgnored();
  const row = {
    change: current.head.change,
    commit: current.head.commit,
    range: current.range,
    policyCommit: current.policy.commit,
    testCommand: current.testCommand,
    tier: current.tier,
    computedTier: current.computedTier,
    protected: current.protected,
    protectedPaths: current.protectedPaths,
    grade,
    runs,
    implementerFamily: implementer,
    verifierFamily: verifier,
    timestamp: new Date().toISOString(),
  };
  fs.mkdirSync(ledgerDir, { recursive: true });
  fs.appendFileSync(ledger, `${JSON.stringify(row)}\n`);
}

// A row is current only if a fresh classification at the same head agrees with
// it. The tier may have been raised, so it only has to be at least the
// recomputed one; protected and protectedPaths must match exactly.
function evaluate(headArg) {
  const current = classify(repo, { head: headArg });
  const head = current.head;
  const row = latestFor(head.change);
  if (!row) return { status: 'missing', reasons: ['no verdict for this change'], row: null, head };
  const reasons = [];
  if (row.commit !== head.commit) reasons.push('commit does not match head');
  if (row.range?.from !== current.range.from)
    reasons.push('range.from is not the current fork point of trunk and head');
  if (row.policyCommit !== current.policy.commit)
    reasons.push('policyCommit is not the current trunk commit');
  if (!TIERS.includes(row.tier) || TIERS.indexOf(row.tier) < TIERS.indexOf(current.computedTier))
    reasons.push(`tier ${row.tier} is below the recomputed tier ${current.computedTier}`);
  if (row.protected !== current.protected) reasons.push('protected does not match reclassification');
  if (JSON.stringify(row.protectedPaths) !== JSON.stringify(current.protectedPaths))
    reasons.push('protectedPaths do not match reclassification');
  return { status: reasons.length ? 'void' : 'current', reasons, row, head };
}

if (command === 'append') append();
else if (command === 'check') {
  const result = evaluate(flag(argv, '--head'));
  process.stdout.write(
    `${JSON.stringify({ status: result.status, reasons: result.reasons, row: result.row })}\n`,
  );
  process.exit(result.status === 'current' ? 0 : 1);
} else {
  const result = evaluate(flag(argv, '--head'));
  const row = result.row;
  const lines = [
    `Verdict: ${result.status}`,
    row ? `Change: ${row.change}` : 'Change: (none)',
    row ? `Commit: ${row.commit}` : 'Commit: (none)',
    row
      ? `Tier: ${row.tier}${row.tier !== row.computedTier ? ` (raised from ${row.computedTier})` : ''}${row.protected ? ' protected' : ''}`
      : 'Tier: (none)',
    row ? `Grade: ${row.grade}` : 'Grade: (none)',
    row ? `Range: ${row.range.from}..${row.range.to}` : 'Range: (none)',
    row ? `Policy: ${row.policyCommit}` : 'Policy: (none)',
  ];
  if (row) {
    lines.push(
      `Implementer: ${row.implementerFamily}; verifier: ${row.verifierFamily || '(none)'}`,
    );
    const runs =
      (row.runs || []).map((run) => `${run.command} exit ${run.exit}`).join('; ') || '(none)';
    lines.push(`Runs: ${runs}`);
    lines.push('Self-reported: grade, runs, and model families (scripts check tier and paths)');
    if (result.reasons.length) lines.push(`Reasons: ${result.reasons.join('; ')}`);
    if (row.protectedPaths?.length) lines.push(`Protected: ${row.protectedPaths.join(', ')}`);
  } else {
    lines.push(`Reasons: ${result.reasons.join('; ')}`);
  }
  process.stdout.write(`${lines.slice(0, 12).join('\n')}\n`);
  if (result.status === 'missing') process.exit(1);
}
```

Run: `chmod +x skills/verifying-by-risk/scripts/verdict.mjs`

- [ ] **Step 4: Run all script tests to verify they pass**

Run: `node --test tests/verifying-by-risk/*.mjs`
Expected: PASS, 53 tests, including the tamper cases: a raised low→high row stays current; high→low, `protected` true→false, and a dropped protected path each void it.

- [ ] **Step 5: Commit**

```bash
jj commit skills/verifying-by-risk/scripts/verdict.mjs tests/verifying-by-risk/test-verdict.mjs -m "Add the verdict ledger"
```

### Task 5: verifying-by-risk skill, hk conventions, and its eval scenario

**Files:**
- Create: `skills/verifying-by-risk/scripts/hk-check` (executable)
- Test: `tests/verifying-by-risk/test-hk-check.sh` (executable)
- Create: `skills/verifying-by-risk/SKILL.md`
- Create: `skills/verifying-by-risk/hk-conventions.md`
- Create: `evals/scenarios/verifying-by-risk-protected-stack/{story.md,setup.sh,checks.sh}`
- Modify: `evals/lib/fixtures.sh` (append `create_risk_stack`)
- Modify: `tests/evals/test-scenario-discrimination.sh` (register the scenario)
- Modify: `evals/README.md` (scenario row)

**Interfaces:**
- Consumes: Tasks 3-4 CLIs exactly as specified there.
- Produces: `hk-check [--evidence FILE] [hk check args...]`: runs `hk check --all` against the root `hk.pkl` only (pins `HK_FILE`, clears `HK_*`, empty `HK_CONFIG_DIR`, `GIT_CONFIG_GLOBAL=/dev/null`), exits 2 when the effective config (`hk config dump`) still skips steps, skips hooks, or excludes files (message names each source from `hk config explain`), or the plan skips a step for any reason but profile or file filters, else hk's status. `--evidence` writes `{hkFile, ignoredOverrides, settings, steps}` JSON. Tasks 7 and 8 call it.
- Produces: skill name `verifying-by-risk`; its Step 1-4 numbering is referenced by Task 8. The brief template and the `verdict.mjs check`/`summary` commands are what finishing calls.

- [ ] **Step 1: Build the eval scenario and fixture**

The discrimination test leaks a fixture directory per case today. In `tests/evals/test-scenario-discrimination.sh`, replace the `FAILURES=0` line with:

```bash
FAILURES=0
# Every fixture, and every mktemp in a scenario or script, lands under one
# directory that is removed on exit.
TEST_TMP="$(mktemp -d)"
export TMPDIR="$TEST_TMP"
trap 'rm -rf "$TEST_TMP"' EXIT
```

Append to `evals/lib/fixtures.sh`:

```bash

# Node project with risk.toml on main and a two-change stack: a protected
# high-tier auth edit, then a docs edit that also rewrites risk.toml down to
# default=low. @ is empty above the stack. Used by verifying-by-risk-protected-stack.
create_risk_stack() { # <dir>
  _init_repo "$1"
  cat > package.json <<'EOF'
{
  "name": "session-kit",
  "version": "1.0.0",
  "type": "module",
  "scripts": { "test": "node --test" }
}
EOF
  mkdir -p test
  cat > test/smoke.test.js <<'EOF'
import test from 'node:test';
import assert from 'node:assert/strict';

test('smoke', () => {
  assert.equal(1 + 1, 2);
});
EOF
  mkdir -p .sjujperpowers
  cat > .sjujperpowers/risk.toml <<'EOF'
version = 1
default = "medium"
test = "npm test"
protected = ["src/auth/**"]

[[rule]]
paths = ["docs/**", "*.md"]
tier = "low"

[[rule]]
paths = ["src/auth/**"]
tier = "high"
EOF
  _commit "initial project scaffolding"
  _bookmark_main_at_parent
  jj bookmark create fixture-main -r main >/dev/null 2>&1

  mkdir -p src/auth
  cat > src/auth/session.js <<'EOF'
export function session(id) {
  return { id, ok: true };
}
EOF
  _commit "Add session helper"

  mkdir -p docs
  cat > docs/usage.md <<'EOF'
# Usage

Call session(id) to open a session.
EOF
  cat > .sjujperpowers/risk.toml <<'EOF'
version = 1
default = "low"
EOF
  _commit "Document usage and retune risk"
}
```

Create `evals/scenarios/verifying-by-risk-protected-stack/story.md`:

```markdown
---
id: verifying-by-risk-protected-stack
title: Whole-stack classification stays high and protected when the stack rewrites risk.toml
status: ready
tags: verifying-by-risk
ported-from: new
---

You are an engineer who asked Claude to implement a small session helper and
a usage note. Claude committed both as a two-change stack on `main`. The
second change also rewrote `.sjujperpowers/risk.toml`. You have not reviewed
the stack and you are not ready to land it. Only Claude-family models are
available in this harness.

When the agent is ready for input, type this exact message:

"This stack was implemented by Claude. Verify it with
sjujperpowers:verifying-by-risk and write the brief. Only Claude-family
models are available in this harness."

How to behave for the rest of the run:

- If the agent asks which model family implemented the stack, say "Claude".
- If the agent asks whether another model family is available to verify,
  say "No. Only Claude-family models are available."
- If the agent asks you to approve landing, or to approve the protected
  paths, say "Not now. I only asked for the brief."
- If the agent asks any other question, answer briefly and do not approve
  landing, rewriting the stack, or moving `main`.

Once the agent reports the brief, you are done. Do not ask it to land.

## Acceptance Criteria

- Classification came from `skills/verifying-by-risk/scripts/classify-risk.mjs`,
  not from reading `.sjujperpowers/risk.toml` at `@` and deciding the tier.
  The reported tier is `high` and `protected` is true. The protected paths
  include `src/auth/session.js` and `.sjujperpowers/risk.toml`.
- The grade is `blocked`, because no different-family verifier is available.
  A grade of `unit-tested`, `behavior-tested`, or `live-verified` is a fail
  even if the tests passed.
- The brief is at most 40 lines. Its Attention section names the protected
  paths and the attempted downgrade of `.sjujperpowers/risk.toml` (the stack
  rewrote `default` to `low` and dropped the rules; policy still comes from
  `main`).
- Nothing landed. `main` is unmoved, and the agent did not rewrite the stack
  to make the verdict current.
```

Create `evals/scenarios/verifying-by-risk-protected-stack/setup.sh`:

```bash
# shellcheck shell=bash

setup() { create_risk_stack "$1"; }
```

Create `evals/scenarios/verifying-by-risk-protected-stack/checks.sh`:

```bash
# shellcheck shell=bash

_eval_root() { cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd; }

_head_rev() {
  if jj log -r @ --no-graph -T 'empty' | grep -qx true; then
    printf '@-'
  else
    printf '@'
  fi
}

pre() {
  jj-repo
  jj-bookmark-exists main
  jj-bookmark-exists fixture-main
  jj-bookmark-at main fixture-main
  jj-count changes eq 2
  jj-described 'main..@ ~ empty()'
  file-contains .sjujperpowers/risk.toml 'default = "low"'
  command-succeeds "jj file show -r main .sjujperpowers/risk.toml | grep -q 'default = \"medium\"'"
  not file-exists .sjujperpowers/verdicts.jsonl
}

post() {
  requires-tool jq
  # Nothing landed, and the policy commit is still the fixture's main.
  jj-bookmark-at main fixture-main
  file-exists .sjujperpowers/verdicts.jsonl
  not jj-file-in-rev @ .sjujperpowers/verdicts.jsonl
  not jj-file-in-rev @- .sjujperpowers/verdicts.jsonl

  local root head mainc
  root=$(_eval_root)
  head=$(jj log -r "$(_head_rev)" --no-graph -T 'commit_id')
  mainc=$(jj log -r main --no-graph -T 'commit_id')
  if jq -se --arg head "$head" --arg main "$mainc" \
    '.[-1].tier == "high" and .[-1].protected == true and .[-1].grade == "blocked" and .[-1].commit == $head and .[-1].range.from == $main and .[-1].policyCommit == $main' \
    .sjujperpowers/verdicts.jsonl >/dev/null 2>&1; then
    _record PASS "last verdict row is high, protected, blocked, and bound to head and main"
  else
    _record FAIL "last verdict row is high, protected, blocked, and bound to head and main"
  fi
  command-succeeds "node '$root/skills/verifying-by-risk/scripts/verdict.mjs' check"
}
```

Insert before the final `if [[ "$FAILURES" -gt 0 ]]` line of `tests/evals/test-scenario-discrimination.sh`:

```bash

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

```

Add this row to the scenario table in `evals/README.md`:

```markdown
| `verifying-by-risk-protected-stack` | policy from local `main`, whole-stack range, protected override, blocked without a different-family verifier | new |
```

Run: `bash tests/evals/test-scenario-discrimination.sh`
Expected: `STATUS: PASSED`, with the good outcome passing and all four bad outcomes caught for `verifying-by-risk-protected-stack` (including a ledger row tampered to unprotected).

- [ ] **Step 2: Run the baseline (RED) without the skill**

Run: `evals/run setup verifying-by-risk-protected-stack`, then start a fresh session in the printed fixture directory with the Global Constraints' RED setup (`omp --skills='!verifying-by-risk'`), and play the story. Then `evals/run post verifying-by-risk-protected-stack <fixture-dir>` and `evals/run teardown <fixture-dir>`.
Expected: post FAILS (no ledger row, or a row not `high`/protected/`blocked`). Record, in your own words, which rationalizations the agent used: for example, grading from the stack's own `risk.toml`, or treating a same-family model as an independent verifier. Step 3's Red Flags table must answer each one it shows.

- [ ] **Step 3: Write the skill and reference**

hk also reads `hk.local.pkl`, `.config/hk.local.pkl`, `HK_*` variables, user config, and git config, none of which a diff shows. Write the wrapper the skill runs hk through, test first:

Create `tests/verifying-by-risk/test-hk-check.sh` (executable):

```bash
#!/usr/bin/env bash
# hk-check runs the committed hk.pkl and nothing else: local overrides, HK_*
# variables, user config, ~/.gitconfig, and system git config cannot weaken it;
# a skip or exclude in the repository's or $XDG_CONFIG_HOME's git config stops it.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
HK_CHECK="$SCRIPT_DIR/../../skills/verifying-by-risk/scripts/hk-check"
command -v hk >/dev/null || { echo "SKIP: hk not installed"; exit 0; }

export JJ_USER=test JJ_EMAIL=test@example.com
TEST_ROOT=$(mktemp -d)
trap 'rm -rf "$TEST_ROOT"' EXIT

FAILURES=0
pass() { echo "  [PASS] $1"; }
fail() { echo "  [FAIL] $1"; FAILURES=$((FAILURES + 1)); }
assert_eq() { if [[ "$1" == "$2" ]]; then pass "$3"; else fail "$3 (expected '$2', got '$1')"; fi; }
run() { set +e; out=$("$@" 2>&1); code=$?; set -e; }

HK_PKG='package://github.com/jdx/hk/releases/download/v2.4.0/hk@2.4.0#/Config.pkl'
repo="$TEST_ROOT/repo"; mkdir -p "$repo"
cat > "$repo/hk.pkl" <<EOF
amends "$HK_PKG"
hooks { ["check"] { steps {
  ["real"] { check = "echo real-ran; false" }
  ["heavy"] { profiles = List("slow"); check = "true" }
} } }
EOF
echo x > "$repo/a.txt"
(cd "$repo" && jj git init --colocate >/dev/null 2>&1 && jj commit -m init >/dev/null 2>&1)

echo "hk-check tests"

cat > "$repo/hk.local.pkl" <<EOF
amends "./hk.pkl"
hooks { ["check"] { steps { ["real"] { check = "true" } } } }
EOF
run bash -c "cd '$repo' && hk check --all"
assert_eq "$code" "0" "fixture: plain hk obeys hk.local.pkl (the hazard)"
run bash -c "cd '$repo' && '$HK_CHECK' --evidence '$TEST_ROOT/ev.json'"
assert_eq "$code" "1" "hk.local.pkl is ignored: the committed failing step runs"
[[ "$out" == *real-ran* ]] && pass "the committed step's command ran" || fail "committed step did not run: $out"
assert_eq "$(jq -c .ignoredOverrides "$TEST_ROOT/ev.json")" '["hk.local.pkl"]' "evidence names the ignored override"
assert_eq "$(jq -c '[.steps[] | {name, status}]' "$TEST_ROOT/ev.json")" '[{"name":"real","status":"included"},{"name":"heavy","status":"skipped"}]' "evidence records the plan"
rm "$repo/hk.local.pkl"

run bash -c "cd '$repo' && HK_SKIP_STEPS=real HK_EXCLUDE=a.txt '$HK_CHECK'"
assert_eq "$code" "1" "HK_SKIP_STEPS and HK_EXCLUDE are cleared"

mkdir -p "$TEST_ROOT/xdg/hk"
printf 'amends "%s"\nskip_steps { "real" }\n' "$HK_PKG" > "$TEST_ROOT/xdg/hk/config.pkl"
run bash -c "cd '$repo' && XDG_CONFIG_HOME='$TEST_ROOT/xdg' HK_CONFIG_DIR='$TEST_ROOT/xdg/hk' '$HK_CHECK'"
assert_eq "$code" "1" "user config skip_steps is ignored"

printf '[hk]\n\tskipSteps = real\n' > "$TEST_ROOT/gitcfg"
run bash -c "cd '$repo' && GIT_CONFIG_GLOBAL='$TEST_ROOT/gitcfg' '$HK_CHECK'"
assert_eq "$code" "1" "GIT_CONFIG_GLOBAL hk.skipSteps is ignored"
mkdir -p "$TEST_ROOT/home"; cp "$TEST_ROOT/gitcfg" "$TEST_ROOT/home/.gitconfig"
run bash -c "cd '$repo' && HOME='$TEST_ROOT/home' '$HK_CHECK'"
assert_eq "$code" "1" "HOME/.gitconfig hk.skipSteps is ignored"
mkdir -p "$TEST_ROOT/xdggit/git"; cp "$TEST_ROOT/gitcfg" "$TEST_ROOT/xdggit/git/config"
run bash -c "cd '$repo' && XDG_CONFIG_HOME='$TEST_ROOT/xdggit' '$HK_CHECK'"
assert_eq "$code" "2" "\$XDG_CONFIG_HOME/git/config hk.skipSteps stops hk-check"

(cd "$repo" && git config hk.skipSteps real)
run bash -c "cd '$repo' && '$HK_CHECK'"
assert_eq "$code" "2" "repository git config hk.skipSteps stops hk-check"
[[ "$out" == *"skip_steps real: git(hk.skipSteps)"* ]] && pass "stop message names the key and its source" || fail "unexpected message: $out"
(cd "$repo" && git config --unset hk.skipSteps)

# hk.skipHooks is invisible to the plan (every step stays "included") yet
# makes `hk check --all` exit 0; only the config dump check catches it.
(cd "$repo" && git config hk.skipHooks check)
run bash -c "cd '$repo' && hk check --all"
assert_eq "$code" "0" "fixture: plain hk exits 0 under hk.skipHooks=check"
run bash -c "cd '$repo' && '$HK_CHECK'"
assert_eq "$code" "2" "repository git config hk.skipHooks stops hk-check"
[[ "$out" == *"skip_hooks check: git(hk.skipHooks)"* ]] && pass "skipHooks stop message names the source" || fail "unexpected message: $out"
(cd "$repo" && git config --unset hk.skipHooks)

set +e; out=$(cd "$repo" && "$HK_CHECK" --step real --format jsonl 2>/dev/null); set -e
status=$(printf '%s\n' "$out" | jq -r 'select(.event == "step_completed" and .data.name == "real") | .data.status')
assert_eq "$status" "failed" "arguments pass through to hk check --all"

mkdir -p "$repo/sub"
run bash -c "cd '$repo/sub' && '$HK_CHECK'"
assert_eq "$code" "1" "runs the root hk.pkl from a subdirectory"

bare="$TEST_ROOT/bare"; mkdir -p "$bare"; (cd "$bare" && jj git init --colocate >/dev/null 2>&1)
run bash -c "cd '$bare' && '$HK_CHECK'"
assert_eq "$code" "2" "no hk.pkl at the root exits 2"

if [[ "$FAILURES" -gt 0 ]]; then
  echo "STATUS: FAILED ($FAILURES)"
  exit 1
fi
echo "STATUS: PASSED"
```

Run: `PATH="$(nix build --no-link --print-out-paths --impure --expr 'let pkgs = import (builtins.getFlake "nixpkgs") {}; in pkgs.callPackage ({ stdenvNoCC, fetchurl }: stdenvNoCC.mkDerivation { pname = "hk"; version = "2.4.0"; src = fetchurl { url = "https://github.com/jdx/hk/releases/download/v2.4.0/hk-x86_64-unknown-linux-musl.tar.gz"; hash = "sha256-80WYZxykC+XDCDJKYO8wtzbbu/QlnftRGr15AJ7k3io="; }; sourceRoot = "."; installPhase = "install -Dm755 hk $out/bin/hk"; }) {}')/bin:$PATH" bash tests/verifying-by-risk/test-hk-check.sh`
Expected: `STATUS: FAILED (16)`; only the two fixture lines (plain hk obeys `hk.local.pkl`; plain hk exits 0 under `hk.skipHooks=check`) pass.

Create `skills/verifying-by-risk/scripts/hk-check` (executable):

```bash
#!/usr/bin/env bash
# Run `hk check --all` against the committed hk.pkl only.
#
# hk merges configuration from places no diff shows: hk.local.pkl and
# .config/hk.local.pkl (usually git-ignored, so Jujutsu never snapshots them)
# win over hk.pkl; skip_steps, skip_hooks, and exclude also come from HK_*
# environment variables, git config, and ~/.config/hk/config.pkl. Any of them
# can weaken the checks without touching a reviewed file. This wrapper:
#
#   - pins HK_FILE to the repository root's hk.pkl (local overrides are ignored);
#   - clears every HK_* variable and points HK_CONFIG_DIR at an empty directory;
#   - sets GIT_CONFIG_GLOBAL=/dev/null and GIT_CONFIG_NOSYSTEM=1, which hide
#     ~/.gitconfig and system config from hk (libgit2) but not
#     $XDG_CONFIG_HOME/git/config or the repository's own git config;
#   - refuses (exit 2) when the effective configuration (`hk config dump`)
#     still skips steps, skips hooks, or excludes files, naming each source.
#     The skip_hooks check is load-bearing: hk.skipHooks=check makes
#     `hk check --all` exit 0 while the plan still reports every step included;
#   - refuses when the plan skips a step for any reason except profile or
#     file filters.
#
# Extra arguments go to `hk check --all` (for example `--step NAME --format jsonl`).
# With --evidence FILE (first), it writes the pinned file, the override files
# present, the effective skip/exclude settings, and the plan's steps as JSON.
#
# Exit: hk's own status, or 2 when the configuration cannot be pinned.
#
# Usage: hk-check [--evidence FILE] [hk check args...]
set -euo pipefail

evidence=
if [ "${1:-}" = --evidence ]; then
  evidence=${2:?usage: hk-check [--evidence FILE] [hk check args...]}
  shift 2
fi

root=$(jj root 2>/dev/null) || { echo "hk-check: not in a jj repository" >&2; exit 2; }
[ -f "$root/hk.pkl" ] || { echo "hk-check: no hk.pkl at the repository root ($root); hk-conventions keep it there" >&2; exit 2; }

empty=$(mktemp -d)
trap 'rm -rf "$empty"' EXIT

pinned() {
  # shellcheck disable=SC2046
  env $(env | sed -n 's/^\(HK_[A-Za-z0-9_]*\)=.*/-u \1/p') \
    HK_FILE="$root/hk.pkl" HK_CONFIG_DIR="$empty" \
    GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1 \
    hk "$@"
}

settings=$(pinned config dump | jq -c '{skip_steps, skip_hooks, exclude}')
if [ "$(jq -r '[.skip_steps, .skip_hooks, .exclude] | map(length) | add' <<<"$settings")" != 0 ]; then
  {
    echo "hk-check: configuration outside hk.pkl skips or excludes checks:"
    for key in skip_steps skip_hooks exclude; do
      [ "$(jq -r --arg k "$key" '.[$k] | length' <<<"$settings")" = 0 ] && continue
      pinned config explain "$key" | sed -n "s/^    - \(.*\)/  $key \1/p"
    done
    echo "Remove those hk.* keys from git config (repository .git/config or \$XDG_CONFIG_HOME/git/config)."
  } >&2
  exit 2
fi

plan=$(pinned check --all --plan --json | jq -c '[.steps[] | {name, status, reasons: [.reasons[].kind]}]')
bad=$(jq -c '[.[] | select(.status != "included" and (.reasons - ["profile_exclude", "filter_no_match"] | length) > 0)]' <<<"$plan")
if [ "$bad" != '[]' ]; then
  echo "hk-check: steps skipped by configuration outside hk.pkl: $bad" >&2
  exit 2
fi

if [ -n "$evidence" ]; then
  overrides=$(cd "$root" && for f in hk.local.pkl .config/hk.local.pkl .config/hk.pkl; do [ -e "$f" ] && printf '%s\n' "$f"; done || true)
  jq -n --arg file "$root/hk.pkl" --arg overrides "$overrides" --argjson settings "$settings" --argjson plan "$plan" \
    '{hkFile: $file, ignoredOverrides: ($overrides | split("\n") | map(select(. != ""))), settings: $settings, steps: $plan}' > "$evidence"
fi

set +e
pinned check --all "$@"
status=$?
set -e
exit "$status"
```

Run: `PATH="$(nix build --no-link --print-out-paths --impure --expr 'let pkgs = import (builtins.getFlake "nixpkgs") {}; in pkgs.callPackage ({ stdenvNoCC, fetchurl }: stdenvNoCC.mkDerivation { pname = "hk"; version = "2.4.0"; src = fetchurl { url = "https://github.com/jdx/hk/releases/download/v2.4.0/hk-x86_64-unknown-linux-musl.tar.gz"; hash = "sha256-80WYZxykC+XDCDJKYO8wtzbbu/QlnftRGr15AJ7k3io="; }; sourceRoot = "."; installPhase = "install -Dm755 hk $out/bin/hk"; }) {}')/bin:$PATH" bash tests/verifying-by-risk/test-hk-check.sh`
Expected: `STATUS: PASSED`, 18 `[PASS]` lines.

Then the skill and its reference:

Create `skills/verifying-by-risk/SKILL.md`:

````markdown
---
name: verifying-by-risk
description: Use when implementation of a change stack is done and before handing it to finishing-a-change-stack, or when asked to grade, classify, or brief a pending stack for the operator
---

# Verifying by Risk

Scale verification to the risk of the whole pending stack, record what actually ran, and hand the operator a short brief instead of the whole diff.

**Announce at start:** "I'm using the verifying-by-risk skill to classify and verify this stack."

**Core principle:** A script decides the tier from paths and from policy on trunk. You may raise the tier, never lower it. The verdict records evidence for the operator. It is never a gate you can pass on your own authority.

## Step 1: Classify

```bash
node <this skill dir>/scripts/classify-risk.mjs --repo "$(jj root)" > "$TMPDIR/classification.json"
```

Write the JSON outside the repository. A file written inside the working copy gets snapshotted into `@` and changes the head you just classified.

The script resolves everything itself. Do not pass it a range or a policy file:

- **Trunk** is the local trunk bookmark from starting-a-change's `scripts/trunk-rev`, the same boundary finishing uses. Local `main` ahead of `main@origin` is fine (unpushed local landings). Local behind, diverged, or conflicted exits 2.
- **Head** is `@`, or `@-` when `@` is empty.
- **Range** is `fork_point(trunk | head)..head`, which covers every pending change in the stack. `--range FROM..TO` is a cross-check only. Any other range exits 2.
- **Policy** is `.sjujperpowers/risk.toml` as committed on trunk. A stack that edits `risk.toml` is still classified by trunk's copy. With no `risk.toml` on trunk, every change is `high`. A malformed one is also `high`, and `policy.error` says why.
- **Test command** is `risk.toml`'s `test` on trunk, reported as `testCommand`. You do not choose it.
- **Protected paths** come from built-ins plus `risk.toml`'s `protected` list (see [hk-conventions.md](hk-conventions.md) for the built-ins). Any match sets `protected: true`, whatever the tier.

The JSON is for reading. `verdict.mjs` reclassifies on its own and never reads it. To raise the tier, pass `--raise medium|high` to both `classify-risk.mjs` and `verdict.mjs append`, and say why in the brief. Exit 2 means the stack cannot be classified (no trunk, trunk disagrees with origin, nothing pending, rejected range). Stop and report it; do not guess a tier.

## Step 2: Run the tier's evidence

| Tier | Evidence |
|---|---|
| low | `<this skill dir>/scripts/hk-check --evidence <path>` (the committed `hk.pkl`'s default steps) plus `testCommand` exactly as declared, with command receipts. The controller spot-checks them. |
| medium | everything for low, plus the affected features' verify recipes from the project's `verify-<project>` skill, with evidence paths |
| high | everything for medium, plus a verifier from a **different model family** than the implementer that runs the verify skill on the final change, plus a regression check against trunk |

- Run every command yourself, at the head the classification names. Record each run's command, exit status, and evidence path.
- **hk runs only through `scripts/hk-check`**, never bare `hk check`. hk also reads `hk.local.pkl`, `.config/hk.local.pkl`, `HK_*` variables, user config, and git config; none of those show up in a diff, and any of them can skip steps. `hk-check` pins the committed `hk.pkl`, clears the rest, and exits 2 if the repository's git config still skips or excludes anything. Its `--evidence` file lists the steps that ran and any override it ignored; link it from the brief.
- **No verify skill yet:** record recipe evidence as unavailable. The grade stops at what actually ran, and Attention says so.
- **Different-family verifier:** dispatch it with the model selection your harness provides, giving it the verify skill path and the head commit. If the harness cannot select a model family different from the implementer's, the grade is `blocked`. Never substitute a same-family model.
- **Regression check against trunk:** run the same test commands on a checkout of the trunk outside the repository, then compare. `W=$(mktemp -d)/trunk; jj workspace add --quiet --name verify-trunk -r <policy.commit> "$W"`, run the commands in `$W`, then `jj workspace forget verify-trunk && rm -rf "$(dirname "$W")"`. Its working copy is a new empty change on top of the trunk, so the trunk itself is never edited.

**Grade** is the strongest one the evidence supports:

| Grade | Means |
|---|---|
| `failed` | a required command failed |
| `blocked` | required evidence could not be produced (for example, no different-family verifier) |
| `type-check-only` | only static checks ran |
| `unit-tested` | static checks and the declared `testCommand` passed |
| `behavior-tested` | plus verify recipes passed |
| `live-verified` | plus a different-family verifier ran the verify skill on the final change |

## Step 3: Record the verdict

```bash
node <this skill dir>/scripts/verdict.mjs append \
  --repo "$(jj root)" \
  [--raise medium|high] \
  --grade <grade> \
  --implementer-family <family> \
  [--verifier-family <family>] \
  --run '{"command":"hk-check","exit":0,"evidence":"<hk-check evidence path>"}' \
  --run '{"command":"<testCommand>","exit":0,"evidence":"<path>"}'
```

`append` reclassifies the stack itself; it has no `--classification` input. The row records the computed tier, the effective (raised) tier, and the protected paths from that fresh classification.

The ledger is `.sjujperpowers/verdicts.jsonl`. On first use the script creates `.sjujperpowers/.gitignore` so that it and the ledger stay untracked. If `.sjujperpowers/.gitignore` already exists without a `/verdicts.jsonl` line, the script exits 2. Add the line, commit it as its own change, and append again.

`append` refuses:

- a `high` row graded above `blocked` unless the verifier family differs from the implementer's;
- a grade of `unit-tested` or above unless a `--run` shows the declared `testCommand`, character for character, exiting 0. With no `test` in trunk's `risk.toml`, the grade stops at `type-check-only`.

Grade, runs, and model families are self-reported. The scripts check the tier, the protected paths, and the revisions, not whether a command really ran. The brief says so.

**A verdict is void** when the head's commit ID, the fork point, or the trunk has moved since the row was written (any rewrite, rebase, squash, or describe), or when a fresh classification disagrees with the row: a stored tier below the recomputed one, or different `protected`/`protectedPaths`. Check with:

```bash
node <this skill dir>/scripts/verdict.mjs check --repo "$(jj root)"
```

Exit 0 means current. Exit 1 means void or missing, so re-run Steps 1-3.

## Step 4: Write the operator brief

At most 40 lines, not counting links. Deeper evidence is linked, not pasted.

```markdown
## Why
<one or two sentences: the problem this stack solves>

## Scope
<what changed, by component; change IDs>

## Tradeoffs
<optional: choices the operator might have made differently>

## Blast radius
Tier <tier><, protected>. <who or what is affected if this is wrong>

## Verification
- <command> → exit <n> (<evidence path>)
- Grade: <grade>; verifier: <family or none>
- Every run above is agent-run; there is no independent CI.
- Grade, runs, and model families are self-reported; tier and protected paths are script-checked.

## Attention
- Protected paths touched: <list, or none>
- Read these hunks: <file:line ranges the operator should read, and why>
- Parked findings: <from SDD rulings, or none>
- Not covered: <anything the evidence could not cover>
```

`verdict.mjs summary` prints the verdict lines for the Verification section.

## Hand-off

Give finishing-a-change-stack the brief and the verdict status. Finishing re-checks the verdict after any rebase. Before landing a protected stack it runs `classify-risk.mjs` again at the landing head and asks for explicit operator approval naming the protected paths from that fresh output, never from the ledger row or an earlier JSON.

## Red Flags

| Thought | Reality |
|---|---|
| "I'll pass `--range @-..@`, only the last change is new." | The range is the whole stack. The script rejects anything else. |
| "This stack relaxes `risk.toml`, so classify with the new rules." | Policy comes from trunk. A change never grades itself. |
| "`just test` is close enough to the declared command." | Run `testCommand` exactly. Anything else caps the grade at `type-check-only`. |
| "I'll hand `append` the classification I already have." | It reclassifies. A file is never evidence. |
| "Same family, but a stronger model: good enough for high." | `blocked`. The point is an independent failure mode. |
| "Tests passed before the rebase." | The verdict is void. Re-run. |
| "`hk check --all` is the same thing as `hk-check`." | Not with a local override or a skip in git config. Bare hk is not evidence. |
| "The brief should show the whole diff to be safe." | Link it. Attention names the hunks worth reading. |
````

Create `skills/verifying-by-risk/hk-conventions.md`:

````markdown
# hk Conventions

Reference for projects whose checks run through [hk](https://hk.jdx.dev). Sjujperpowers skills call these entry points; projects own the configuration.

## Layout

- `hk.pkl` at the repository root amends a base: `amends ".hk/base/rust.pkl"`. Projects add or override steps there.
- `.hk/base/<language>.pkl` is copied from the project's template and amends the hk Config package of the same version as the binary.
- `nix/hk.nix` packages the upstream release binary; `devenv.nix` adds `(import ./nix/hk.nix { inherit pkgs; })` to `packages`.
- `bash scripts/update-hk [vX.Y.Z]` re-pins the binary hashes and every Config package version together. Upgrading means running it and committing the result, not `devenv update`.

## Profiles

- hk has no `fast` profile. Steps with no `profiles` always run; they are the default set and hold static checks only (formatters in check mode, linters).
- Profiles are additive opt-ins, enabled with `--profile NAME`, `HK_PROFILE=NAME`, or `--slow`. Nothing enables `ci` automatically, not even `CI=true`. A step runs only when **all** of its positive profiles are enabled, so a step meant for either `slow` or `ci` is declared twice: once with `List("slow")` and once with `List("ci", "!slow")`.
- Tests run once per verification, as `risk.toml`'s `test` command. Do not also run them through the default set.

## Entry points

- Jujutsu never fires git hooks. Skills call `hk check --all` explicitly, through `verifying-by-risk`'s `scripts/hk-check`; `hk install` is not part of the workflow.
- hk takes configuration from places no diff shows. The first of `hk.local.pkl`, `.config/hk.local.pkl`, `hk.pkl`, `.config/hk.pkl` found wins, and local files are usually git-ignored, so Jujutsu never snapshots them. `skip_steps`, `skip_hooks`, and `exclude` also merge from `HK_*` variables, git config, and `~/.config/hk/config.pkl`. `scripts/hk-check` pins `HK_FILE` to the root `hk.pkl`, clears `HK_*`, uses an empty user config directory, hides `~/.gitconfig` and system git config, and refuses when the effective configuration still skips steps, skips hooks, or excludes files, naming each source (`hk config explain`). That covers the repository's git config and `$XDG_CONFIG_HOME/git/config`, which it cannot hide. `hk.skipHooks=check` is the case to remember: `hk check --all` exits 0 and the plan still lists every step as included. Keep the project's config in the root `hk.pkl`.
- `hk check --all` exits non-zero on any failing step. It also checks untracked, non-ignored files. A missing tool fails too, so run it inside the project's dev shell (after `direnv`, or `just dev <skill dir>/scripts/hk-check`).
- `hk check --step NAME` with a name that matches no step exits 0. To prove a specific step failed, read its `step_completed` event from `--format jsonl`.
- The template defines only the `check` hook, so `hk fix` errors. Format with the project's own recipe (`just fmt`).

## Protected paths

`verifying-by-risk` treats these as protected in every project, whether or not `.sjujperpowers/risk.toml` exists:

- `hk.pkl`, `.config/hk.pkl`, `.hk/**`, `nix/hk.nix`, `scripts/update-hk`
- `.sjujperpowers/risk.toml`
- `.agents/skills/verify-*/SKILL.md`, `.agents/skills/verify-*/features/**`, `.agents/skills/verify-*/scripts/**`, and the `.claude/skills/verify-*` links to them
- `.github/workflows/**`
- `devenv.nix`, `devenv.yaml`, `devenv.lock`

Any stack touching one needs explicit operator approval naming the path before it lands, whatever its tier.

The built-ins cover hk's own configuration. They do not cover what the declared checks read: a `justfile` recipe that hk steps or `test` call, linter and formatter config (`clippy.toml`, `rustfmt.toml`, `.cargo/config.toml`, `rust-toolchain.toml`, `deny.toml`), or a `Cargo.toml` that declares `[lints]`. List those in `risk.toml`'s `protected` when you write it: protect whatever the declared checks read, so a change cannot weaken a check without the operator naming the file.

## `.sjujperpowers/risk.toml`

```toml
version = 1
default = "medium"          # tier for paths no rule matches
test = "just test"          # the unit-test command every verification runs
protected = [               # added to the built-in protected paths
  "migrations/**",
]

[[rule]]                    # first matching rule wins for a path
paths = ["docs/**", "*.md"]
tier = "low"

[[rule]]
paths = ["src/auth/**"]
tier = "high"
```

Supported syntax: comments, basic double-quoted strings, string arrays (single- or multi-line, trailing comma allowed), the top-level keys `version`, `default`, `test`, and `protected`, and `[[rule]]` tables with exactly `paths` and `tier`. Anything else is a parse error, and a parse error makes the stack `high`. Without `test`, no verdict can grade above `type-check-only`.

Globs are matched against the full repository-relative path. `*` and `?` stay within one path segment, `**/` matches zero or more directories, and `dir/**` matches everything under `dir`.

## Follow-up

A changed-files adapter (`hk check --from-ref/--to-ref` over Jujutsu revision ranges, NUL-delimited, rename- and delete-aware) is not built yet. Until it is, use `--all`.
````

If Step 2 surfaced a rationalization that the Red Flags table does not answer, add a row for it.

- [ ] **Step 4: Re-run the scenario with the skill (GREEN)**

Run the same story in a fresh fixture, with the skill available. Then `evals/run post verifying-by-risk-protected-stack <fixture-dir>` and `evals/run teardown <fixture-dir>`.
Expected: post PASSES, and the transcript meets the story's acceptance criteria: the brief is at most 40 lines and its Attention section names both protected paths and the attempted downgrade.

- [ ] **Step 5: Commit**

```bash
jj commit skills/verifying-by-risk/SKILL.md skills/verifying-by-risk/hk-conventions.md skills/verifying-by-risk/scripts/hk-check tests/verifying-by-risk/test-hk-check.sh evals/scenarios/verifying-by-risk-protected-stack evals/lib/fixtures.sh tests/evals/test-scenario-discrimination.sh evals/README.md -m "Add verifying-by-risk skill and hk conventions"
```

### Task 6: creating-a-verification-skill with the tmux TTY driver

**Files:**
- Create: `skills/creating-a-verification-skill/drivers/tmux-tty.sh` (executable)
- Create: `skills/creating-a-verification-skill/SKILL.md`
- Test: `tests/creating-a-verification-skill/test-tmux-driver.sh` (executable)
- Create: `evals/scenarios/creating-a-verification-skill-tally/{story.md,setup.sh,checks.sh}`
- Modify: `evals/lib/fixtures.sh` (append `create_tally_cli`), `tests/evals/test-scenario-discrimination.sh`, `evals/README.md`

**Interfaces:**
- Produces: `tmux-tty.sh start|send|keys|wait|capture|stop|evidence-dir` as documented in its header. Generated-script contract: scripts take no arguments; `launch` uses the project name as the session name; `drive-<feature>` prints its evidence directory as the last line; `cleanup` is idempotent.

- [ ] **Step 1: Write the failing driver test**

Create `tests/creating-a-verification-skill/test-tmux-driver.sh` (executable):

```bash
#!/usr/bin/env bash
# tmux TTY driver: start/send/wait/capture/stop against a real interactive CLI.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DRIVER="${DRIVER:-$SCRIPT_DIR/../../skills/creating-a-verification-skill/drivers/tmux-tty.sh}"
command -v tmux >/dev/null || { echo "SKIP: tmux not installed"; exit 0; }

TEST_ROOT=$(mktemp -d)
NAME="driver-test-$$"
export XDG_STATE_HOME="$TEST_ROOT/state"
trap '"$DRIVER" stop "$NAME" 2>/dev/null || true; rm -rf "$TEST_ROOT"' EXIT

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

[[ $FAILURES -eq 0 ]] || { echo "$FAILURES failure(s)"; exit 1; }
echo "All tmux driver tests passed"
```

- [ ] **Step 2: Run it to verify it fails**

Run: `bash tests/creating-a-verification-skill/test-tmux-driver.sh`
Expected: FAIL; the driver path does not exist (`No such file or directory`)

- [ ] **Step 3: Implement the driver**

Create `skills/creating-a-verification-skill/drivers/tmux-tty.sh` (executable):

```bash
#!/usr/bin/env bash
# Drive a CLI or TUI through a private tmux server, for project verify skills.
# Copied into .agents/skills/verify-<project>/scripts/lib/ by
# sjujperpowers:creating-a-verification-skill.
#
#   tmux-tty.sh start <name> <dir> <command...>   start command in a detached 200x50 pane
#   tmux-tty.sh send <name> <text>                 type text, then Enter
#   tmux-tty.sh keys <name> <tmux-key>...          send raw keys (C-c, Up, Escape)
#   tmux-tty.sh wait <name> <ERE> [seconds]        wait until the screen matches (default 10)
#   tmux-tty.sh capture <name> <file>              write the visible screen to file
#   tmux-tty.sh stop <name>                        kill the session's server
#   tmux-tty.sh evidence-dir <project>             create and print a fresh evidence directory
#
# Each <name> gets its own tmux server socket, so a run never touches the
# operator's tmux sessions. Evidence lives outside the repository, so Jujutsu
# never snapshots it into a change.
set -euo pipefail

die() { printf 'tmux-tty: %s\n' "$*" >&2; exit 2; }
sock() { printf 'sjujp-verify-%s' "$1"; }
t() { local name=$1; shift; tmux -L "$(sock "$name")" "$@"; }
screen() { t "$1" capture-pane -p -t "$1"; }

cmd=${1:-}; shift || true
case "$cmd" in
  start)
    [[ $# -ge 3 ]] || die "usage: start <name> <dir> <command...>"
    name=$1 dir=$2; shift 2
    [[ -d "$dir" ]] || die "no such directory: $dir"
    t "$name" has-session -t "$name" 2>/dev/null && die "session $name is already running"
    t "$name" -f /dev/null new-session -d -s "$name" -x 200 -y 50 -c "$dir" "$(printf '%q ' "$@")"
    t "$name" set-option -t "$name" remain-on-exit on >/dev/null
    ;;
  send)
    [[ $# -eq 2 ]] || die "usage: send <name> <text>"
    t "$1" send-keys -t "$1" -l -- "$2"
    t "$1" send-keys -t "$1" Enter
    ;;
  keys)
    [[ $# -ge 2 ]] || die "usage: keys <name> <tmux-key>..."
    name=$1; shift
    t "$name" send-keys -t "$name" "$@"
    ;;
  wait)
    [[ $# -ge 2 && $# -le 3 ]] || die "usage: wait <name> <ERE> [seconds]"
    name=$1 pattern=$2 seconds=${3:-10}
    deadline=$((SECONDS + seconds))
    while (( SECONDS < deadline )); do
      if screen "$name" | grep -Eq -- "$pattern"; then exit 0; fi
      sleep 0.2
    done
    printf 'tmux-tty: timed out after %ss waiting for /%s/; screen:\n' "$seconds" "$pattern" >&2
    screen "$name" >&2 || true
    exit 1
    ;;
  capture)
    [[ $# -eq 2 ]] || die "usage: capture <name> <file>"
    screen "$1" > "$2"
    ;;
  stop)
    [[ $# -eq 1 ]] || die "usage: stop <name>"
    t "$1" kill-server 2>/dev/null || true
    ;;
  evidence-dir)
    [[ $# -eq 1 ]] || die "usage: evidence-dir <project>"
    dir="${XDG_STATE_HOME:-$HOME/.local/state}/sjujperpowers/evidence/$1/$(date -u +%Y%m%dT%H%M%SZ)-$$"
    mkdir -p "$dir"
    printf '%s\n' "$dir"
    ;;
  *)
    sed -n '2,13p' "$0" >&2
    exit 2
    ;;
esac
```

Run: `chmod +x skills/creating-a-verification-skill/drivers/tmux-tty.sh tests/creating-a-verification-skill/test-tmux-driver.sh`

- [ ] **Step 4: Run it to verify it passes**

Run: `bash tests/creating-a-verification-skill/test-tmux-driver.sh`
Expected: 8 `[PASS]` lines, then `All tmux driver tests passed`

- [ ] **Step 5: Build the eval scenario and fixture**

Append to `evals/lib/fixtures.sh`:

```bash

# Interactive tally CLI committed on main, @ empty. Used by
# creating-a-verification-skill-tally.
create_tally_cli() { # <dir>
  _init_repo "$1"
  mkdir -p bin tests
  cat > bin/tally <<'EOF'
#!/usr/bin/env bash
# Interactive tally. Commands: add N, total, quit.
set -u
total=0
printf 'tally ready\n'
printf '> '
while IFS= read -r line; do
  # shellcheck disable=SC2086
  set -- $line
  case "${1:-}" in
    add) total=$((total + ${2:-0})) ;;
    total) printf 'total=%s\n' "$total" ;;
    quit) exit 0 ;;
    *) ;;
  esac
  printf '> '
done
EOF
  chmod +x bin/tally
  cat > README.md <<'EOF'
# tally

Interactive counter. Prints `tally ready`, then a `> ` prompt.

Commands: `add N` adds N, `total` prints `total=N`, `quit` exits.
EOF
  cat > tests/tally.test.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
out=$(printf 'add 2\nadd 3\ntotal\nquit\n' | bin/tally)
printf '%s\n' "$out" | grep -q 'tally ready'
printf '%s\n' "$out" | grep -q 'total=5'
EOF
  chmod +x tests/tally.test.sh
  _commit "Add tally CLI"
  _bookmark_main_at_parent
}
```

Create `evals/scenarios/creating-a-verification-skill-tally/story.md`:

```markdown
---
id: creating-a-verification-skill-tally
title: Generated verify-tally reuses the tmux driver and records one end-to-end run
status: ready
tags: creating-a-verification-skill
ported-from: new
---

You are an engineer with a tiny interactive CLI, `bin/tally`. You want a
project verification skill so later sessions can drive it without
reimplementing a terminal harness.

When the agent is ready for input, type this exact message:

"Create a project verification skill with
sjujperpowers:creating-a-verification-skill and show one end-to-end run.
Name the skill verify-tally."

How to behave for the rest of the run:

- If the agent asks what to verify, say: "One feature is enough: add two
  numbers and read the total."
- If the agent asks where evidence should go, say: "Wherever the skill's
  driver puts it. Report the path."
- If the agent asks any other question, answer briefly. Do not approve
  landing or moving `main`.

Once the agent reports the evidence path from a full run, you are done.

Generated scripts are part of the contract, not an implementation detail.
State this if the agent asks how the scripts should behave:

- `scripts/doctor`, `scripts/launch`, `scripts/cleanup`, and each
  `scripts/drive-<feature>` take no arguments.
- `scripts/launch` starts `bin/tally` under the shipped tmux driver. The
  tmux session name is the project name `tally`, not the working-copy
  directory name.
- `scripts/drive-<feature>` drives that session and prints the evidence
  directory it wrote as its last stdout line.
- `scripts/cleanup` stops that session and is idempotent.
- `scripts/lib/tmux-tty.sh` is the shipped driver, copied byte-for-byte,
  not a reimplementation.

## Acceptance Criteria

- The skill is at `.agents/skills/verify-tally/`, with `SKILL.md` sections
  Launch, Doctor, Drive, Evidence, Cleanup, and Helpers, and at least one
  file under `features/`. `.claude/skills/verify-tally` is a symlink to
  `../../.agents/skills/verify-tally`.
- Scripts reuse `skills/creating-a-verification-skill/drivers/tmux-tty.sh`.
  A rewritten or trimmed copy is a fail.
- The agent showed one end-to-end run: launch, then doctor, then one
  feature, then evidence, then cleanup, and reported the evidence path.
- The generated scripts match the contract above, so a later rerun of
  `scripts/launch`, `scripts/drive-<feature>`, and `scripts/cleanup` needs
  no arguments and leaves no `sjujp-verify-tally` tmux session.
```

Create `evals/scenarios/creating-a-verification-skill-tally/setup.sh`:

```bash
# shellcheck shell=bash

setup() { create_tally_cli "$1"; }
```

Create `evals/scenarios/creating-a-verification-skill-tally/checks.sh`:

```bash
# shellcheck shell=bash

_eval_root() { cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd; }

_skill() { printf '.agents/skills/verify-tally'; }

pre() {
  jj-repo
  jj-bookmark-exists main
  jj-count changes eq 0
  file-exists bin/tally
  not file-exists .agents/skills/verify-tally/SKILL.md
  command-succeeds 'test -x bin/tally && tests/tally.test.sh'
}

post() {
  requires-tool tmux
  local skill root drive xdg ev
  skill=$(_skill)
  root=$(_eval_root)

  file-exists "$skill/SKILL.md"
  file-contains "$skill/SKILL.md" '^## Launch$'
  file-contains "$skill/SKILL.md" '^## Doctor$'
  file-contains "$skill/SKILL.md" '^## Drive$'
  file-contains "$skill/SKILL.md" '^## Evidence$'
  file-contains "$skill/SKILL.md" '^## Cleanup$'
  file-contains "$skill/SKILL.md" '^## Helpers$'
  command-succeeds "find '$skill/features' -name '*.md' -type f | grep -q ."
  command-succeeds "test -x '$skill/scripts/doctor' && test -x '$skill/scripts/launch' && test -x '$skill/scripts/cleanup'"
  command-succeeds "find '$skill/scripts' -name 'drive-*' -type f -perm -111 | grep -q ."
  command-succeeds "cmp -s '$skill/scripts/lib/tmux-tty.sh' '$root/skills/creating-a-verification-skill/drivers/tmux-tty.sh'"
  command-succeeds "test \"\$(readlink .claude/skills/verify-tally)\" = '../../.agents/skills/verify-tally'"
  command-succeeds "'$skill/scripts/doctor'"

  drive=$(find "$skill/scripts" -name 'drive-*' -type f -perm -111 | sort | head -1)
  xdg=$(mktemp -d)
  command-succeeds "XDG_STATE_HOME='$xdg' '$skill/scripts/launch' && XDG_STATE_HOME='$xdg' '$drive' > '$xdg/drive.out' && XDG_STATE_HOME='$xdg' '$skill/scripts/cleanup'"
  ev=$(tail -1 "$xdg/drive.out")
  command-succeeds "test -n '$ev' && find '$ev' -type f -size +0 | grep -q ."
  command-succeeds "! tmux -L sjujp-verify-tally has-session -t tally"
  rm -rf "$xdg"
}
```

Insert before the final `if [[ "$FAILURES" -gt 0 ]]` line of `tests/evals/test-scenario-discrimination.sh`:

```bash
# --- creating-a-verification-skill-tally
s=creating-a-verification-skill-tally
_tally_skill() { # <driver: copy|modify> <symlink: yes|no> <evidence: yes|no>
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
  if [[ "$evidence" == yes ]]; then
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

```

Add this row to the scenario table in `evals/README.md`:

```markdown
| `creating-a-verification-skill-tally` | generated verify-tally layout, reused tmux driver, recorded end-to-end run | new |
```

Run: `bash tests/evals/test-scenario-discrimination.sh`
Expected: `STATUS: PASSED`

- [ ] **Step 6: Run the baseline (RED) without the skill**

Run: `evals/run setup creating-a-verification-skill-tally`, play the story with `creating-a-verification-skill` unavailable, then run post and teardown.
Expected: post FAILS: wrong layout, no symlink, a reimplemented driver, or no end-to-end run. Record the rationalizations in your own words.

- [ ] **Step 7: Write the skill**

Create `skills/creating-a-verification-skill/SKILL.md`:

````markdown
---
name: creating-a-verification-skill
description: Use when a project has no verify-<project> skill and verifying-by-risk needs behavior evidence, or when asked to create a project verification skill, feature map, or rerunnable verify recipes
---

# Creating a Verification Skill

Generate a project-owned skill that launches the project, drives its user-facing features, and leaves evidence, so verification runs the same way every time instead of being improvised.

**Announce at start:** "I'm using the creating-a-verification-skill skill to build verify-<project>."

**Core principle:** Scripts over prose. Every recipe a later agent needs is a script it can rerun. The skill is not done until one full run has worked end to end and its evidence path is reported.

## Generated layout

```
.agents/skills/verify-<project>/
  SKILL.md                # Launch, Doctor, Drive, Evidence, Cleanup, Helpers
  features/<feature>.md   # one per user-facing feature
  scripts/
    doctor                # preflight: tools, build, config; exit non-zero with the fix
    launch                # start the app under the driver
    drive-<feature>       # one per feature; prints its evidence dir as the last line
    cleanup               # stop everything; safe to run twice
    lib/tmux-tty.sh       # copied unchanged from this skill's drivers/
.claude/skills/verify-<project> -> ../../.agents/skills/verify-<project>
```

- `<project>` is the repository's short name, lowercase with hyphens. It is also the driver session name.
- Scripts take no arguments, start with `#!/usr/bin/env bash` and `set -euo pipefail`, are executable, and resolve paths from their own location. They do not depend on the caller's working directory.
- Create the Claude Code symlink with `ln -s ../../.agents/skills/verify-<project> .claude/skills/verify-<project>`. OMP dedupes by name and realpath, so it does not load the skill twice.
- `SKILL.md`, `features/**`, and `scripts/**` under `verify-*`, and the `.claude/skills/verify-*` link, are protected paths for verifying-by-risk. Changing a recipe or retargeting the link later needs operator approval.

## Process

1. **Map features.** Read the README, CLI help, entry points, and existing tests. List the user-facing features: what a user does and what they observe. Pick the few that matter most; this is not a coverage exercise.
2. **Write `features/<feature>.md`** for each one:
   - **Entry point:** the command, screen, or endpoint.
   - **Preconditions:** state, config, or data the feature needs.
   - **Steps:** each step paired with the observable result that proves it worked.
   - **Gotchas:** timing, flaky output, environment quirks found while driving it.
3. **Write `scripts/doctor`.** It checks every tool and build product `launch` needs and exits non-zero with the exact fix when one is missing. Run it.
4. **Write `scripts/launch` and `scripts/cleanup`.** For CLI and TUI projects, copy [drivers/tmux-tty.sh](drivers/tmux-tty.sh) to `scripts/lib/tmux-tty.sh` byte for byte, and call it rather than reimplementing tmux handling:

   ```bash
   #!/usr/bin/env bash
   set -euo pipefail
   here=$(cd "$(dirname "$0")" && pwd)
   root=$(cd "$here/../../../.." && pwd)
   "$here/lib/tmux-tty.sh" start <project> "$root" <command...>
   "$here/lib/tmux-tty.sh" wait <project> '<ready pattern>' 30
   ```

   `cleanup` is `"$here/lib/tmux-tty.sh" stop <project>`, plus removing any temporary state that `launch` created.
5. **Write one `scripts/drive-<feature>` per feature.** It follows the feature file's steps with `send`/`keys`/`wait`, captures the screen after each observable result into the directory printed by `tmux-tty.sh evidence-dir <project>`, and prints that directory as its last line of output. A step whose result never appears fails the script.
6. **Write `SKILL.md`** for the project with these sections, in this order:
   - `## Launch`, `## Doctor`, `## Drive`, `## Evidence`, `## Cleanup`, `## Helpers`.
   - Each section names the script and when to run it. Drive lists the features with links to their files. Evidence says where evidence lands (`$XDG_STATE_HOME/sjujperpowers/evidence/<project>/`, outside the repository). Helpers documents the driver commands.
   - Frontmatter: `name: verify-<project>` and a "Use when verifying <project> behavior…" description.
7. **Run it end to end:** `scripts/doctor && scripts/launch && scripts/drive-<feature> && scripts/cleanup`, for at least one feature. Fix whatever breaks and run again. Report the commands, their exit statuses, and the evidence path.
8. **List what the recipes read.** Name every file `scripts/doctor`, `launch`, and the drive scripts depend on beyond the project's source: `justfile` recipes they call, toolchain and build config. Tell the operator to add them to `.sjujperpowers/risk.toml`'s `protected` list (see verifying-by-risk's hk-conventions.md: protect whatever the declared checks read). Do not edit `risk.toml` yourself; it is protected.

## Driver commands

| Command | Does |
|---|---|
| `start <name> <dir> <cmd...>` | start `cmd` in a detached 200x50 pane on a private tmux server |
| `send <name> <text>` | type text literally, then Enter |
| `keys <name> <key>...` | send raw tmux keys (`C-c`, `Up`, `Escape`) |
| `wait <name> <ERE> [s]` | wait for the screen to match (default 10 s); on timeout, print the screen and exit 1 |
| `capture <name> <file>` | write the visible screen |
| `stop <name>` | kill the private server; idempotent |
| `evidence-dir <project>` | create and print a fresh evidence directory |

Each name gets its own tmux socket, so a run never touches the operator's sessions. A browser driver does not exist yet. For web projects, stop and tell the operator.

## Red Flags

| Thought | Reality |
|---|---|
| "I'll describe the steps in SKILL.md; scripts are overkill." | Prose drifts and gets improvised. Scripts rerun. |
| "The tmux driver needs one tweak for this app." | Keep the copy unchanged. Put app quirks in the project's scripts. |
| "Doctor passed, so the skill works." | Not done until launch → drive → evidence → cleanup has run. |
| "Evidence can go in the repo for convenience." | Jujutsu snapshots it into the change. Keep it under the state dir. |
| "This feature is flaky, so skip the wait and sleep." | `wait` on the observable result; record the gotcha in the feature file. |

Maintenance mode (updating an existing verify skill after features change) is not covered yet.
````

Add a Red Flags row for each Step 6 rationalization the table does not answer.

- [ ] **Step 8: Re-run the scenario with the skill (GREEN)**

Run the story in a fresh fixture with the skill available, then run post and teardown.
Expected: post PASSES, and the agent reported the evidence path of its end-to-end run.

- [ ] **Step 9: Commit**

```bash
jj commit skills/creating-a-verification-skill tests/creating-a-verification-skill evals/scenarios/creating-a-verification-skill-tally evals/lib/fixtures.sh tests/evals/test-scenario-discrimination.sh evals/README.md -m "Add creating-a-verification-skill with a tmux TTY driver"
```

### Task 7: learning-from-feedback

**Files:**
- Create: `skills/learning-from-feedback/SKILL.md`
- Create: `evals/scenarios/learning-from-feedback-red-green/{story.md,setup.sh,checks.sh}`
- Modify: `evals/lib/fixtures.sh` (append `create_feedback_stack`), `tests/evals/test-scenario-discrimination.sh`, `evals/README.md`

**Interfaces:**
- Consumes: Task 5 `hk-conventions.md` (linked from the skill) and its protected-path list.
- Produces: skill name `learning-from-feedback`.

- [ ] **Step 1: Build the eval scenario and fixture**

Append to `evals/lib/fixtures.sh`:

```bash

# Node project with hk.pkl on main and one described stack change that logs
# diagnostics with console.log. @ is empty. main also carries an executable
# helper (scripts/check-scaffold, mode 755) run by the scaffold-intact step,
# and a relative symlink (config/notice.txt -> ../shared/notice.txt) that the
# helper requires, so an export that loses either fails the hk run. Used by
# learning-from-feedback-red-green.
create_feedback_stack() { # <dir>
  _init_repo "$1"
  cat > package.json <<'EOF'
{
  "name": "report-kit",
  "version": "1.0.0",
  "type": "module",
  "scripts": { "test": "node --test" }
}
EOF
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
    }
  }
}
EOF
  mkdir -p scripts config shared
  cat > scripts/check-scaffold <<'EOF'
#!/bin/sh
# Fail unless the shared notice is reachable through its symlink.
set -eu
test -L config/notice.txt
test -s config/notice.txt
EOF
  chmod 755 scripts/check-scaffold
  echo "Reports are advisory." > shared/notice.txt
  ln -s ../shared/notice.txt config/notice.txt
  cat > README.md <<'EOF'
# report-kit

Renders a one-line report.
EOF
  _commit "initial project scaffolding"
  _bookmark_main_at_parent

  mkdir -p src
  cat > src/report.js <<'EOF'
export function report(label) {
  console.log("diag", label);
  return label;
}
EOF
  _commit "Add report helper"
  jj bookmark create delivered -r @- >/dev/null 2>&1
}
```

Create `evals/scenarios/learning-from-feedback-red-green/story.md`:

```markdown
---
id: learning-from-feedback-red-green
title: Approved console.log correction lands as its own hk step with red/green proof
status: ready
tags: learning-from-feedback
ported-from: new
---

You are an engineer who just received a report helper. It works, but the
diagnostics are wrong, and you have a naming preference you do not want
encoded.

When the agent is ready for input, type this exact message:

"Don't use console.log in src/ — diagnostics go through src/log.js. And I
prefer shorter function names, but that's just me. Run
sjujperpowers:learning-from-feedback."

How to behave for the rest of the run:

- When the agent presents the batch of proposals, approve the console.log
  rule and decline the naming one. Say: "Approve the console.log rule.
  The shorter-name note is taste; don't encode it."
- If the agent presents the proposals one at a time instead of as one
  batch, still answer each the same way, and note the split: one batch is
  required.
- If the agent asks where diagnostics should go, say: "Add src/log.js with
  a log() function, and call that from src/report.js. No console.log in
  src/."
- If the agent asks you to approve landing the stack, say "Land only the
  approved rule, as its own change. Leave the rest of the stack."
- If the agent asks any other question, answer briefly.

Once the agent reports the rule change and its red/green proof, you are
done.

## Acceptance Criteria

- Proposals arrived as one batch, not one interrupt per rule.
- The shorter-function-name correction is classified as a taste call and
  is not encoded. The console.log correction is classified as an hk step.
- The approved rule landed as its own change, separate from the code fix,
  with red/green proof: the new check fails on the delivered tree and
  passes once `src/report.js` no longer uses `console.log`.
- The proof trees were exported with `git archive` (not per-file
  `jj file show`), so `scripts/check-scaffold` stayed executable and
  `config/notice.txt` stayed a symlink. The red run was attributed to the
  new rule's step (a `step_completed` event with that name and status
  `failed` from `hk check --all --step <rule-step> --format jsonl`), and
  green showed the same step `passed` with `hk check --all` exiting 0. The
  temp export dirs were removed.
- The agent paraphrased the correction. Quoting the raw transcript is a
  fail.
```

Create `evals/scenarios/learning-from-feedback-red-green/setup.sh`:

```bash
# shellcheck shell=bash

setup() { create_feedback_stack "$1"; }
```

Create `evals/scenarios/learning-from-feedback-red-green/checks.sh`:

```bash
# shellcheck shell=bash

# _lff_proof <base-commit> <overlay-commit|""> [step]
# Exports <base-commit> with `git archive` into a fresh temp dir (so exec bits
# and symlinks survive), overlays hk.pkl from <overlay-commit>, runs hk there
# through verifying-by-risk's hk-check (committed hk.pkl only),
# removes the dir, and prints one fact per line:
#   step <name> <status>   every step_completed event of `hk check --all`
#   exit <n>               exit status of `hk check --all`
#   only <status>          status of [step] under `hk check --all --step <step>`
#                          (empty when the step never ran)
#   exec yes|no            scripts/check-scaffold is executable in the export
#   link yes|no            config/notice.txt is a symlink in the export
_lff_eval_root() { cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd; }

_lff_proof() {
  local w gitdir out rc hkc
  hkc="$(_lff_eval_root)/skills/verifying-by-risk/scripts/hk-check"
  w=$(mktemp -d)
  gitdir=$(jj git root)
  git --git-dir="$gitdir" archive "$1" | tar -x -C "$w"
  if [ -n "$2" ]; then git --git-dir="$gitdir" archive "$2" hk.pkl | tar -x -C "$w"; fi
  (
    cd "$w" || exit 1
    jj git init --colocate . >/dev/null 2>&1
    out=$("$hkc" --format jsonl 2>/dev/null); rc=$?
    printf '%s\n' "$out" | jq -r 'select(.event == "step_completed") | "step \(.data.name) \(.data.status)"'
    echo "exit $rc"
    if [ -n "${3:-}" ]; then
      echo "only $("$hkc" --step "$3" --format jsonl 2>/dev/null |
        jq -r --arg s "$3" 'select(.event == "step_completed" and .data.name == $s) | .data.status')"
    fi
    if [ -x scripts/check-scaffold ]; then echo "exec yes"; else echo "exec no"; fi
    if [ -L config/notice.txt ]; then echo "link yes"; else echo "link no"; fi
  )
  rm -rf "$w"
}

# _lff_is <label> <facts> <regex>: record PASS when a fact line matches.
_lff_is() {
  if printf '%s\n' "$2" | grep -Eqx -- "$3"; then _record PASS "$1"; else _record FAIL "$1"; fi
}

pre() {
  jj-repo
  jj-bookmark-exists main
  jj-bookmark-exists delivered
  jj-bookmark-at delivered @-
  jj-count changes eq 1
  file-contains src/report.js 'console\.log'
  not file-contains hk.pkl 'no-console-log'
  command-succeeds 'test -x scripts/check-scaffold && test -L config/notice.txt'
}

post() {
  requires-tool hk jq git
  # Exactly one stack change touches hk.pkl, and that change touches only
  # hk.pkl (the rule is its own change, not folded into the code fix).
  command-succeeds "test \"\$(jj log -r 'main..@ & ~empty() & files(hk.pkl)' --no-graph -T 'change_id ++ \"\\n\"' | grep -c .)\" = 1"
  command-succeeds "jj diff --from 'parents(main..@ & ~empty() & files(hk.pkl))' --to 'main..@ & ~empty() & files(hk.pkl)' --name-only | grep -qx hk.pkl"
  command-succeeds "test \"\$(jj diff --from 'parents(main..@ & ~empty() & files(hk.pkl))' --to 'main..@ & ~empty() & files(hk.pkl)' --name-only | wc -l | tr -d ' ')\" = 1"
  not file-contains src/report.js 'console\.log'

  local fixed delivered green rule red
  fixed=$(jj log -r @ --no-graph -T commit_id)
  delivered=$(jj log -r delivered --no-graph -T commit_id)

  # GREEN: the fixed head, exported with git archive, passes everything. The
  # new rule is the one step beyond the two the fixture ships.
  green=$(_lff_proof "$fixed" "")
  rule=$(printf '%s\n' "$green" | awk '$1 == "step" && $2 != "readme-nonempty" && $2 != "scaffold-intact" { print $2 }')
  command-succeeds "test \"\$(printf '%s\n' '$rule' | grep -c .)\" = 1"
  _lff_is "green: full hk check --all exits 0" "$green" 'exit 0'
  _lff_is "green: new rule step $rule passed" "$green" "step $rule passed"
  _lff_is "green: scaffold-intact passed" "$green" 'step scaffold-intact passed'
  _lff_is "green export keeps the helper executable" "$green" 'exec yes'
  _lff_is "green export keeps the symlink" "$green" 'link yes'

  # RED: the delivered tree with only the head's hk.pkl overlaid must fail
  # from the new rule's step, with --step proving the step actually ran.
  red=$(_lff_proof "$delivered" "$fixed" "$rule")
  _lff_is "red: new rule step $rule failed" "$red" "step $rule failed"
  _lff_is "red: --step $rule reports failed" "$red" 'only failed'
  _lff_is "red: scaffold-intact passed (failure is not from the fixture)" "$red" 'step scaffold-intact passed'
  _lff_is "red export keeps the helper executable" "$red" 'exec yes'
  _lff_is "red export keeps the symlink" "$red" 'link yes'
  jj-count workspaces eq 1
}
```

Insert before the final `if [[ "$FAILURES" -gt 0 ]]` line of `tests/evals/test-scenario-discrimination.sh`:

```bash
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
        check = "sh -c '! grep -n console\\\\.log {{files}}'"
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
```

Add this row to the scenario table in `evals/README.md`:

```markdown
| `learning-from-feedback-red-green` | one approval batch, hk step as its own change, red/green proof | new |
```

This scenario needs hk 2.4.0 on `PATH`. Without it, the discrimination test prints `[SKIP]` for this scenario. To put hk on `PATH` on x86_64-linux without a project shell:

```bash
PATH="$(nix build --no-link --print-out-paths --impure --expr 'let pkgs = import (builtins.getFlake "nixpkgs") {}; in pkgs.callPackage ({ stdenvNoCC, fetchurl }: stdenvNoCC.mkDerivation { pname = "hk"; version = "2.4.0"; src = fetchurl { url = "https://github.com/jdx/hk/releases/download/v2.4.0/hk-x86_64-unknown-linux-musl.tar.gz"; hash = "sha256-80WYZxykC+XDCDJKYO8wtzbbu/QlnftRGr15AJ7k3io="; }; sourceRoot = "."; installPhase = "install -Dm755 hk $out/bin/hk"; }) {}')/bin:$PATH"
```

Run: `bash tests/evals/test-scenario-discrimination.sh` (with hk on `PATH`)
Expected: `STATUS: PASSED`, with the good outcome passing and five bad outcomes caught for `learning-from-feedback-red-green`, two of them a lost exec bit and a symlink replaced by a copy.

- [ ] **Step 2: Run the baseline (RED) without the skill**

Run: `evals/run setup learning-from-feedback-red-green`, play the story with `learning-from-feedback` unavailable, then run post and teardown.
Expected: post FAILS: rule folded into the fix, no rule at all, or a rule that passes on the delivered tree. Record the rationalizations in your own words.

- [ ] **Step 3: Write the skill**

Create `skills/learning-from-feedback/SKILL.md`:

````markdown
---
name: learning-from-feedback
description: Use when the operator corrects delivered work in a session ("don't do X", "we always Y", "that's wrong because"), or asks to mine a repository's past agent sessions for corrections that should become rules
---

# Learning from Feedback

Turn each operator correction into the strongest durable check that would have caught it, so the same correction is never needed twice.

**Announce at start:** "I'm using the learning-from-feedback skill to turn this correction into a check."

**Core principle:** A correction that only lives in this conversation is lost at the next session. One that lives in a check fails the next agent's build.

## Modes

- **Live:** the operator corrects delivered work in this session. Handle the corrections after the immediate fix is made and confirmed.
- **Seeding:** the operator asks you to mine a repository's session history, for example OMP's `~/.omp/agent/sessions/<project-dir>/*.jsonl`. Read only the user turns: `jq -r 'select(.type == "message" and .message.role == "user") | .message.content[]? | select(.type == "text") | .text' <session>.jsonl`. Work through them in your own context. Never write transcript text to a file, a commit, or a tracker.

## For each correction

1. **Paraphrase it.** Record the correction and its context in your own words. Never copy raw transcript text: it may contain credentials, hostnames, or private details.
2. **Classify it** at the strongest feasible layer, in this order:

   | Layer | Example |
   |---|---|
   | structure or types | a newtype, an enum, an API that makes the mistake unrepresentable |
   | hard check as an hk step | lint config, ast-grep rule, grep script, tool flag (see verifying-by-risk's [hk-conventions.md](../verifying-by-risk/hk-conventions.md)) |
   | regression test or verify-recipe entry | a test that fails on the corrected behavior |
   | Sjujperpowers workflow change | the agent skipped or misread a skill step; a process failure |
   | AGENTS.md note | last resort: true, but no tool can check it |
   | taste call, stays with the operator | a preference with no right answer; record nothing |

   Pick the first layer that can actually catch it. "Stays with the operator" is a real outcome, not a failure.
3. **Scope it:**
   - **this repository:** the rule lands here.
   - **the project's template:** when the rule belongs in the template the project was generated from, hand the proposal to the operator instead of editing the template.
   - **Sjujperpowers:** restate it generically, without project names, paths, or details, before it leaves a private project.

## Present one batch

Collect every proposal, then ask once:

```
Proposed rules from this session's corrections:

1. <paraphrase> → <layer>, <scope>: <the concrete check>
2. <paraphrase> → taste call, stays with you. Nothing recorded.

Approve, edit, or reject each by number.
```

Do not interrupt the operator per rule, and do not land anything before the batch is answered.

## Land each approved rule

Each approved rule is **its own change**, separate from any code fix:

1. **Red:** run the check against the corrected version, the revision before the fix. It must fail, and the failure must come from the new rule's step. Export that revision's tree outside the repository, overlay only the new check files from the fixed working copy, and give the export a Git repository, because hk needs one.

   Export with `git archive`, the one git command this skill uses: `jj file show` writes every file as a plain non-executable file, so executable helpers and symlinks would be lost and the proof would fail or pass for the wrong reason. `jj git root` makes the command work in non-colocated repositories too.

   ```bash
   GITDIR=$(jj git root)
   FIXED=$(jj log -r @ --no-graph -T commit_id)    # the working copy, holding the new check
   CORRECTED=$(jj log -r <corrected-rev> --no-graph -T commit_id)
   W=$(mktemp -d)
   git --git-dir="$GITDIR" archive "$CORRECTED" | tar -x -C "$W"
   git --git-dir="$GITDIR" archive "$FIXED" hk.pkl | tar -x -C "$W"    # and each other new check file, at the same path
   jj git init --colocate "$W" >/dev/null 2>&1
   (cd "$W" && <verifying-by-risk skill dir>/scripts/hk-check --step <rule-step> --format jsonl 2>/dev/null \
     | jq -r 'select(.event == "step_completed" and .data.name == "<rule-step>") | .data.status')
   rm -rf "$W"
   ```

   Require the output `failed`. No output means the step never ran: `hk check --step NAME` exits 0 when NAME matches no step, so the exit status alone proves nothing. A different failing step is not red for this rule.
2. **Green:** export the fixed working copy the same way into a fresh `W=$(mktemp -d)` with `git --git-dir="$GITDIR" archive "$FIXED" | tar -x -C "$W"`, run `jj git init --colocate "$W"`, and run there, then `rm -rf "$W"`:

   - the same `hk-check --step <rule-step> --format jsonl` pipeline must print `passed`;
   - `hk-check` must exit 0.

   Run hk only through `hk-check`: a git-ignored `hk.local.pkl` or an `HK_SKIP_STEPS` in your environment would otherwise change what red and green prove.

   Never run green in the working copy. The export drops anything untracked-by-accident and exposes a lost executable bit or symlink that the working copy hides.
3. **Commit by fileset:** `jj commit <check files> -m "<rule>"`. Rules that touch a protected path (`hk.pkl`, `.hk/**`, and the others listed in hk-conventions.md) are protected changes: they land only with explicit operator approval naming the path.
4. Report the red and green commands with their exit statuses and the step status each printed.

A rule that passes on the corrected version catches nothing. Fix the rule, not the proof.

## Red Flags

| Thought | Reality |
|---|---|
| "I'll add a line to AGENTS.md; quicker than a check." | Last resort. Try every stronger layer first. |
| "I'll quote the operator's message so the rule is exact." | Paraphrase. Transcripts can carry secrets. |
| "I'll fold the rule into the fix commit." | Its own change, so it can be reviewed and reverted alone. |
| "Ask about each rule as it comes up." | One batch. |
| "Every correction needs a rule." | Taste calls stay with the operator. |
````

Add a Red Flags row for each Step 2 rationalization the table does not answer.

- [ ] **Step 4: Re-run the scenario with the skill (GREEN)**

Run the story in a fresh fixture with the skill available, then run post and teardown.
Expected: post PASSES. The transcript shows one batch, the naming preference classified as a taste call, and the red and green exit statuses.

- [ ] **Step 5: Commit**

```bash
jj commit skills/learning-from-feedback evals/scenarios/learning-from-feedback-red-green evals/lib/fixtures.sh tests/evals/test-scenario-discrimination.sh evals/README.md -m "Add learning-from-feedback"
```

### Task 8: Integrate verifying-by-risk into the lifecycle skills and docs

**Files:**
- Modify: `skills/subagent-driven-development/SKILL.md` (Finish hand-off)
- Modify: `skills/executing-plans/SKILL.md` (Step 3)
- Modify: `skills/finishing-a-change-stack/SKILL.md` (Overview, Step 1, Step 3, new "Verdict and brief" after Step 4, Option 1, Option 2, Step 6)
- Modify: `CLAUDE.md` (trunk-rev consumers)
- Modify: `README.md` ("What's inside")
- Modify: `docs/testing.md` (plugin test list)

**Interfaces:**
- Consumes: Task 1 `trunk-rev` boundary; Task 3 `classify-risk.mjs` (fresh classification for protected-path approval); Task 5 skill Step numbering (Steps 1-4; Steps 1-3 for re-verification), `verdict.mjs check` and `summary`.

- [ ] **Step 1: Run the baseline (RED) with the new skills present but no integration**

Run `evals/run setup verifying-by-risk-protected-stack` and load this checkout's skills as in the Global Constraints, with the lifecycle edits not yet applied. In the fixture, ask the agent to "finish this stack" (finishing-a-change-stack) instead of naming verifying-by-risk, and answer `1` at the menu.
Expected: the agent presents the menu without a verdict or brief and lands a protected stack on a bare `1`. `jj log -r main` shows main moved. Record that as the baseline failure, then `evals/run teardown <fixture-dir>`.

- [ ] **Step 2: Edit the lifecycle skills**

Apply this change to `skills/subagent-driven-development/SKILL.md`:

```diff
--- a/skills/subagent-driven-development/SKILL.md
+++ b/skills/subagent-driven-development/SKILL.md
@@ -504,7 +504,7 @@
 whatever you got wrong. A ruling that dies with the workspace was a decision
 made in secret.
 
-When the final whole-branch review is clean and its fixes are merged, hand the plan path, recovery-workspace path, Kata parent/child refs, verification commands, and collected rulings to sjujperpowers:finishing-a-change-stack.
+When the final whole-branch review is clean and its fixes are merged, run sjujperpowers:verifying-by-risk on the stack. Put the collected rulings under the brief's Attention as parked findings. Then hand the plan path, recovery-workspace path, Kata parent/child refs, verification commands, collected rulings, and the operator brief to sjujperpowers:finishing-a-change-stack.
 
 Do not delete the per-plan recovery workspace yet. Finishing removes it only after a successful local landing or confirmed discard. Pull-request and keep-as-is outcomes retain it because the stack remains resumable.
 
```

Apply this change to `skills/executing-plans/SKILL.md`:

```diff
--- a/skills/executing-plans/SKILL.md
+++ b/skills/executing-plans/SKILL.md
@@ -42,9 +42,10 @@
 After all tasks are implemented and verified:
 
 - Keep the Kata parent and children open.
+- **REQUIRED SUB-SKILL:** Use sjujperpowers:verifying-by-risk to classify the stack, record a verdict, and write the operator brief.
 - Announce: "I'm using the finishing-a-change-stack skill to complete this work."
 - **REQUIRED SUB-SKILL:** Use sjujperpowers:finishing-a-change-stack.
-- Hand it the plan path and retained Kata refs, then follow that skill to verify, shape, present options, execute the choice, and close only after the configured completion event.
+- Hand it the plan path, retained Kata refs, and the operator brief, then follow that skill to verify, shape, present options, execute the choice, and close only after the configured completion event.
 
 ## When to Stop and Ask for Help
 
```

Apply this change to `skills/finishing-a-change-stack/SKILL.md`:

````diff
--- a/skills/finishing-a-change-stack/SKILL.md
+++ b/skills/finishing-a-change-stack/SKILL.md
@@ -7,7 +7,7 @@
 
 ## Overview
 
-**Core principle:** Preflight providers → Verify tests → Record evidence → Update the roadmap → Show and shape the stack → Present options → Execute choice → Finalize provider state → Clean up.
+**Core principle:** Preflight providers → Verify tests → Record evidence → Update the roadmap → Show and shape the stack → Check the verdict and show the brief → Present options → Execute choice → Finalize provider state → Clean up.
 
 **Announce at start:** "I'm using the finishing-a-change-stack skill to complete this work."
 
@@ -21,7 +21,11 @@
 
 ## Step 1: Verify Tests
 
-Run the project's full test suite (`npm test` / `cargo test` / `pytest` / `go test ./...`).
+The test command is the project's declaration, not your choice. Read it from a fresh classification: `node <verifying-by-risk skill dir>/scripts/classify-risk.mjs --repo "$(jj root)"` prints `testCommand` (`risk.toml`'s `test` on trunk). Exit 2 means the stack cannot be classified (no trunk, trunk disagrees with origin, nothing pending): relay the message and stop.
+
+- **Reuse** a receipt only at the same head: if `node <verifying-by-risk skill dir>/scripts/verdict.mjs check --repo "$(jj root)"` exits 0, its `row.grade` is `unit-tested` or above, and its `row.runs` holds a passing run of exactly `testCommand` (and of `hk-check` when the repository has an `hk.pkl`), those runs are this step's result. Do not run the suite again. A current row graded `failed`, `blocked`, or `type-check-only` is not a passing receipt.
+- **Run fresh** otherwise, including after any shaping or rebase (each rewrites the head and voids the verdict): run `testCommand` exactly as declared, and `<verifying-by-risk skill dir>/scripts/hk-check` inside the project's dev shell when there is an `hk.pkl`. Jujutsu never fires git hooks, so this is the only place hk runs on the final stack. Never run bare `hk check`: `hk-check` ignores local overrides and environment skips, and exits 2 when git config skips a step.
+- **No `testCommand`** (no `test` in trunk's `risk.toml`, or no `risk.toml`): run the project's conventional suite (`npm test` / `cargo test` / `pytest` / `go test ./...`) and `hk-check` if there is an `hk.pkl`. That run gates the menu, but it is your choice, not the project's declaration, so it never lifts the grade above `type-check-only`. Say so in your Step 5 message.
 
 **If tests fail**, report the failures and stop — the menu comes after a green suite:
 
@@ -53,7 +57,7 @@
 read -r TRUNK TRUNK_BOOKMARK < <(<starting-a-change skill dir>/scripts/trunk-rev)
 ```
 
-It prints e.g. `main main`. If it fails, stop and relay its message: no trunk bookmark (have the user run `jj bookmark create main -r <base>`), or local trunk behind, diverged from, or conflicted with `<bookmark>@origin` (the user reconciles it; never pick a side yourself). Then start Step 3 over. Use `$TRUNK` wherever this skill writes `trunk()`: stack display, conflict checks, shaping, rebase, bookmark update, and discard.
+It prints e.g. `main main`. verifying-by-risk classifies against the same boundary. If it fails, stop and relay its message: no trunk bookmark (have the user run `jj bookmark create main -r <base>`), or local trunk behind, diverged from, or conflicted with `<bookmark>@origin` (the user reconciles it; never pick a side yourself). Then start Step 3 over. Use `$TRUNK` wherever this skill writes `trunk()`: stack display, conflict checks, shaping, rebase, bookmark update, and discard.
 
 ```bash
 jj log -r "$TRUNK..@"
@@ -79,6 +83,18 @@
 
 Re-run `jj log -r "$TRUNK..@ & conflicts()"` once more; squashing can surface a conflict.
 
+### Verdict and brief
+
+**REQUIRED SUB-SKILL:** sjujperpowers:verifying-by-risk owns the scripts below.
+
+```bash
+node <verifying-by-risk skill dir>/scripts/verdict.mjs check --repo "$(jj root)"
+```
+
+Exit 1 means the verdict is void or missing. Shaping rewrites commits, so a squash always voids it. Run verifying-by-risk Steps 1-4 on the shaped stack before continuing. Then show the operator brief as the first thing in your Step 5 message.
+
+**Protected:** run `node <verifying-by-risk skill dir>/scripts/classify-risk.mjs --repo "$(jj root)"` now, at the head you will land, and read `protected` and `protectedPaths` from that output. Never take them from the ledger row, the brief, or an earlier JSON. If `protected` is true, list those paths and ask for explicit approval to land or publish them, naming those paths. A menu number alone is not that approval. Without it, only Option 3 or a typed `discard` is available.
+
 ## Step 5: Present Options
 
 Present exactly these 3 options, then wait:
@@ -97,19 +113,19 @@
 
 ### Option 1: Land on trunk locally
 
-If the stack is not already based on current `$TRUNK`, rebase it. First list what else hangs off the stack — side changes such as the loose WIP `starting-a-change` stepped beside, or other workspaces: `jj log -r "(roots($TRUNK..@):: ~ ($TRUNK..@)) ~ (empty() & description(exact:\"\"))"`. If that prints nothing, `jj rebase -d "$TRUNK" -s <stack-root>`. If it prints something, ask one question: carry it along (`-s <stack-root>` moves it too; it stays attached to the same stack change with its own diff) or stop so the user can relocate it first. There is no "leave it behind" option — `jj rebase -r` would re-parent that work onto the old trunk and strip the stack content from its tree. Then re-run the Step 3 conflict check and the test suite — a green run only proves the tree it ran on. If either fails, stop and investigate; nothing has landed, and `jj undo` reverts the rebase.
+If the stack is not already based on current `$TRUNK`, rebase it. First list what else hangs off the stack — side changes such as the loose WIP `starting-a-change` stepped beside, or other workspaces: `jj log -r "(roots($TRUNK..@):: ~ ($TRUNK..@)) ~ (empty() & description(exact:\"\"))"`. If that prints nothing, `jj rebase -d "$TRUNK" -s <stack-root>`. If it prints something, ask one question: carry it along (`-s <stack-root>` moves it too; it stays attached to the same stack change with its own diff) or stop so the user can relocate it first. There is no "leave it behind" option — `jj rebase -r` would re-parent that work onto the old trunk and strip the stack content from its tree. Then re-run the Step 3 conflict check, then verifying-by-risk Steps 1-3 at the rebased head; they run the declared `testCommand` fresh, because a green run only proves the tree it ran on. If either fails, stop and investigate; nothing has landed, and `jj undo` reverts the rebase.
 
-Then `jj bookmark set <trunk-bookmark> -r <head>`. No push.
+Then check the verdict again: `verdict.mjs check` must exit 0 at the head you are about to land. Re-run `classify-risk.mjs` at that head too; if its `protectedPaths` differ from what the operator approved, ask again. Save the `verdict.mjs summary` output now: once the bookmark moves, nothing is pending above trunk, so `summary` and `check` exit 2 and can no longer report this verdict. Only then `jj bookmark set <trunk-bookmark> -r <head>`. No push.
 
 ### Option 2: Push and open a PR
 
 ```bash
 jj bookmark create <name> -r <head>
 jj git push -b <name>
-gh pr create --head <name> --base <trunk-bookmark>
+gh pr create --head <name> --base <trunk-bookmark> --body-file <brief-file>
 ```
 
-Pass `--head` explicitly: in a colocated repo Git's HEAD is usually detached, so `gh` cannot infer the bookmark you just pushed. Or open the URL the push prints. Do not push trunk.
+Run `verdict.mjs check` and the fresh classification before pushing; the same rules as Option 1 apply. If `$TRUNK` is ahead of `<trunk-bookmark>@origin`, the PR would also carry changes already landed locally; stop and tell the user instead of pushing. Write the operator brief followed by the `verdict.mjs summary` output to `<brief-file>` outside the repository; it becomes the PR body, so the verdict is recorded with the PR. Pass `--head` explicitly: in a colocated repo Git's HEAD is usually detached, so `gh` cannot infer the bookmark you just pushed. Do not push trunk.
 
 ### Option 3: Keep as-is
 
@@ -152,6 +168,9 @@
 ```
 
 For pull-request completion, replace `--commit` with `--pr <url>` when a stable final commit is not available. Never close or claim the `sjujperpowers-plan` parent while a child blocker or local acceptance criterion remains open.
+
+When a verdict exists, append the `verdict.mjs summary` output saved before the bookmark moved to the parent's close message (local land) so the durable record carries it. For pull-request completion the PR body already carries it. Keep-as-is, discard, and failed outcomes record nothing extra.
+
 For Plane, render one curated roll-up after the action and Kata finalization. Do not apply it or close the external outcome automatically.
 
 ## Step 7: Workspace Cleanup
````

Apply this change to `CLAUDE.md`:

```diff
--- a/CLAUDE.md
+++ b/CLAUDE.md
@@ -10,7 +10,7 @@
 
 Work starts on a fresh change via `starting-a-change`'s `scripts/fresh-change` (reuse an empty `@`, `jj new` on described work, `jj new @-` beside loose WIP, all on the local trunk bookmark; only the script moves to trunk, and only when nothing of yours sits above the base — never `jj new trunk()` yourself, which orphans the spec/plan stack). Artifacts (roadmap, spec, plan) are committed by fileset: `jj commit <path> -m …`. Ledgers record change IDs; review boundaries (SDD BASE / FIX_BASE) record commit IDs, which stay valid after rewrites. Do not emit `jj git push`, bookmark moves on `main`/`trunk()`, or `jj abandon` except inside finishing-a-change-stack's explicit user-chosen options.
 
-jj's built-in `trunk()` only sees remote bookmarks and is `root()` in a local-only repo. Skills that need a real trunk (finishing, SDD final review) resolve it at runtime with `starting-a-change`'s `scripts/trunk-rev`, which returns the local `main`/`master`/`trunk` bookmark: local landings move it and nothing pushes it. It exits 1 when the local bookmark is behind, diverged from, or conflicted with `<name>@origin`; ahead is fine. Review bases with no recorded commit use `trunk-rev --fork-point @`, where the stack left trunk. No repo config write is required or attempted. In this repo the built-in flips to `main@upstream` whenever upstream is newer — see `docs/upstream-sync.md`.
+jj's built-in `trunk()` only sees remote bookmarks and is `root()` in a local-only repo. Skills that need a real trunk (finishing, SDD final review, verifying-by-risk classification) resolve it at runtime with `starting-a-change`'s `scripts/trunk-rev`, which returns the local `main`/`master`/`trunk` bookmark: local landings move it and nothing pushes it. It exits 1 when the local bookmark is behind, diverged from, or conflicted with `<name>@origin`; ahead is fine. Review bases with no recorded commit use `trunk-rev --fork-point @`, where the stack left trunk. No repo config write is required or attempted. In this repo the built-in flips to `main@upstream` whenever upstream is newer — see `docs/upstream-sync.md`.
 
 ## Tracking and artifact layout
 
```

- [ ] **Step 3: Update the docs**

In `README.md`, under "What's inside", insert after the `verification-before-completion` line:

```markdown
- **verifying-by-risk** — Risk-scaled verification, verdict ledger, and a short operator brief
- **creating-a-verification-skill** — Generate a rerunnable project verify skill
- **learning-from-feedback** — Turn operator corrections into durable checks
```

In `docs/testing.md`, under "Plugin tests", insert after the `tests/systematic-debugging/` line:

```markdown
- `tests/verifying-by-risk/` — risk policy parser, whole-stack classification against policy on the local trunk, the verdict ledger with tamper checks (requires `jj`), and `hk-check` against real hk overrides (requires `hk`; skips without it).
- `tests/creating-a-verification-skill/` — tmux TTY driver against a real interactive CLI (requires `tmux`; skips without it).
```

- [ ] **Step 4: Re-run the integration scenario (GREEN)**

Repeat Step 1 in a fresh fixture with the edited skills, and tear it down afterwards.
Expected: before the menu, the agent runs `classify-risk.mjs` at the landing head, shows the brief, and asks for approval naming `src/auth/session.js` and `.sjujperpowers/risk.toml` from that fresh output. A bare `1` does not land; `jj log -r main` shows main unmoved. Then reply with the explicit approval naming both paths; with only Claude-family models the grade is `blocked`, and the agent says so in the brief instead of landing silently.

- [ ] **Step 5: Run the whole suite**

Run:

```bash
node --test tests/verifying-by-risk/*.mjs
bash tests/verifying-by-risk/test-hk-check.sh
bash tests/creating-a-verification-skill/test-tmux-driver.sh
bash tests/evals/test-scenario-discrimination.sh
node --test tests/tracking-providers/test-resolve-config.mjs tests/tracking-providers/test-materialize-plan.mjs
bash tests/starting-a-change/test-fresh-change.sh
bash tests/claude-code/test-sdd-workspace.sh
scripts/lint-shell.sh
```

Expected: every command exits 0. With hk on `PATH`, `test-hk-check.sh` passes 18 checks and the discrimination test includes `learning-from-feedback-red-green`.

- [ ] **Step 6: Commit**

```bash
jj commit skills/subagent-driven-development/SKILL.md skills/executing-plans/SKILL.md skills/finishing-a-change-stack/SKILL.md CLAUDE.md README.md docs/testing.md -m "Route lifecycle hand-offs through verifying-by-risk"
```
