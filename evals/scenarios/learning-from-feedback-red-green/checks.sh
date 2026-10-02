# shellcheck shell=bash

# _lff_proof <base-commit> <overlay-commit|""> [step] [fixed-commit]
# Exports <base-commit> with `git archive` into a fresh temp dir (so exec bits
# and symlinks survive), overlays every file the rule change <overlay-commit>
# touches from that commit's diff (its --name-only paths), runs hk there
# (committed hk.pkl only), removes the dir, and prints one fact per line:
#   step <name> <status>   every step_completed event of `hk check --all`
#   exit <n>               exit status of `hk check --all`
#   only <status>          status of [step] under `hk check --all --step <step>`
#                          (empty when the step never ran)
#   exec yes|no            scripts/check-scaffold is executable in the export
#   link yes|no            config/notice.txt is a symlink in the export
# With [step] it also reads that step's failing command and output from the
# `--step` run's run_completed event and prints:
#   dep missing <path>     a path the failing command names that exists in
#                          [fixed-commit]'s tree but not in this export
#   sig file yes|no        the output names src/report.js (the offending file)
#   sig match yes|no       the output names the offending match (console)
#   marker yes|no          the output carries a startup-failure marker (the
#                          command never ran its assertion)
_lff_eval_root() { cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd; }

_lff_proof() {
  local w gitdir out rc hkc only failure output tok
  hkc="$(_lff_eval_root)/skills/verifying-by-risk/scripts/hk-check"
  w=$(mktemp -d)
  gitdir=$(jj git root)
  git --git-dir="$gitdir" archive "$1" | tar -x -C "$w"
  if [ -n "$2" ]; then
    git --git-dir="$gitdir" diff -z --name-only --diff-filter=d "$2^" "$2" |
      while IFS= read -r -d '' f; do
        git --git-dir="$gitdir" archive "$2" -- "$f" | tar -x -C "$w"
      done
  fi
  (
    cd "$w" || exit 1
    jj git init --colocate . >/dev/null 2>&1
    out=$("$hkc" --format jsonl 2>/dev/null); rc=$?
    printf '%s\n' "$out" | jq -r 'select(.event == "step_completed") | "step \(.data.name) \(.data.status)"'
    echo "exit $rc"
    if [ -n "${3:-}" ]; then
      only=$("$hkc" --step "$3" --format jsonl 2>/dev/null)
      echo "only $(printf '%s\n' "$only" |
        jq -r --arg s "$3" 'select(.event == "step_completed" and .data.name == $s) | .data.status')"
      failure=$(printf '%s\n' "$only" | jq -r 'select(.event == "run_completed") | .data.failure // empty')
      output=$(printf '%s\n' "$only" | jq -r --arg s "$3" \
        'select(.event == "run_completed") | .data.steps[] | select(.name == $s) | .output // empty')
      # Every path the failing command names that the fixed tree has must be here.
      if [ -n "${4:-}" ]; then
        set -f
        for tok in $(printf '%s\n' "$failure" | tr -d "\"'"); do
          tok=${tok#!}; tok=${tok#./}
          [ -n "$tok" ] || continue
          if git --git-dir="$gitdir" cat-file -e "$4:$tok" 2>/dev/null && [ ! -e "$tok" ] && [ ! -L "$tok" ]; then
            echo "dep missing $tok"
          fi
        done
        set +f
      fi
      if printf '%s\n' "$output" | grep -q 'report\.js'; then echo "sig file yes"; else echo "sig file no"; fi
      if printf '%s\n' "$output" | grep -q 'console'; then echo "sig match yes"; else echo "sig match no"; fi
      if printf '%s\n' "$output" | grep -Eq 'command not found|No such file or directory|Cannot find module|MODULE_NOT_FOUND|Permission denied|ModuleNotFoundError'; then
        echo "marker yes"
      else
        echo "marker no"
      fi
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

# _lff_none <label> <facts> <regex>: record PASS when no fact line matches.
_lff_none() {
  if printf '%s\n' "$2" | grep -Eqx -- "$3"; then _record FAIL "$1"; else _record PASS "$1"; fi
}

# _lff_head: @- when @ is empty, else @. The GREEN export is taken from the
# head that holds both the code fix and the rule.
_lff_head() {
  if jj log -r @ --no-graph -T 'empty' | grep -qx true; then printf '@-'; else printf '@'; fi
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
  # Exactly one stack change touches hk.pkl; it may carry the rule's own check
  # files but nothing under src/ (the rule is its own change, not the code fix).
  command-succeeds "test \"\$(jj log -r 'main..@ & ~empty() & files(hk.pkl)' --no-graph -T 'change_id ++ \"\\n\"' | grep -c .)\" = 1"
  # The rule is its own described change, not left uncommitted in @: jj
  # snapshots @, so files(hk.pkl) alone would match a dirty working copy.
  jj-described 'main..@ & ~empty() & files(hk.pkl)'
  command-succeeds "test \"\$(jj log -r 'main..@ & ~empty() & files(hk.pkl)' --no-graph -T commit_id)\" != \"\$(jj log -r @ --no-graph -T commit_id)\""
  command-succeeds "jj diff --from 'parents(main..@ & ~empty() & files(hk.pkl))' --to 'main..@ & ~empty() & files(hk.pkl)' --name-only | grep -qx hk.pkl"
  command-succeeds "test -z \"\$(jj diff --from 'parents(main..@ & ~empty() & files(hk.pkl))' --to 'main..@ & ~empty() & files(hk.pkl)' --name-only | grep -x 'src/.*')\""
  not file-contains src/report.js 'console\.log'

  local head fixed delivered rulechange green rule red
  head=$(_lff_head)
  fixed=$(jj log -r "$head" --no-graph -T commit_id)
  delivered=$(jj log -r delivered --no-graph -T commit_id)
  rulechange=$(jj log -r 'main..@ & ~empty() & files(hk.pkl)' --no-graph -T commit_id)

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

  # RED: the delivered tree with the rule change's files overlaid must fail
  # from the new rule's step, with --step proving the step actually ran.
  red=$(_lff_proof "$delivered" "$rulechange" "$rule" "$fixed")
  _lff_is "red: new rule step $rule failed" "$red" "step $rule failed"
  _lff_is "red: --step $rule reports failed" "$red" 'only failed'
  _lff_is "red: scaffold-intact passed (failure is not from the fixture)" "$red" 'step scaffold-intact passed'
  # A failing exit alone is not red for the rule: Node exits 1 on a missing
  # module, and a missing or non-executable helper exits 127/126. So the
  # rule must carry every path its check names, and the failure output must
  # be the check's own finding (the offending file and match).
  _lff_none "red: the rule change carries every path its check command names" "$red" 'dep missing .*'
  _lff_none "red: exit is a real failure (not 0, 126, or 127)" "$red" 'exit (0|126|127)'
  _lff_is "red: output names the offending file src/report.js" "$red" 'sig file yes'
  _lff_is "red: output names the offending match console.log" "$red" 'sig match yes'
  _lff_is "red: output has no startup-failure marker" "$red" 'marker no'
  _lff_is "red export keeps the helper executable" "$red" 'exec yes'
  _lff_is "red export keeps the symlink" "$red" 'link yes'
  jj-count workspaces eq 1
}
