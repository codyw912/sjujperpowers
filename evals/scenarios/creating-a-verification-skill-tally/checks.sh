# shellcheck shell=bash

_eval_root() { cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd; }

# _final_capture <evidence-dir>: the newest non-empty file, i.e. the last
# screen the drive script captured. Earlier captures are history; the claim is
# about where the run ended.
_final_capture() {
  # A pipeline, not `< <(…)`: process substitution hangs some agent tool shells.
  # The loop runs in the pipeline's subshell, so it prints the winner itself.
  find "$1" -type f -size +0 | sort | {
    local f best=''
    while IFS= read -r f; do
      # Sorted names, so on an mtime tie the later name wins.
      if [[ -z "$best" || ! "$best" -nt "$f" ]]; then best=$f; fi
    done
    printf '%s' "$best"
  }
}

# _tally_result <evidence-dir>: the evidence must show the feature's own result
# ("add two numbers and read the total"), not just that the app started. The
# agent picks the numbers, so read them back from the final capture only (a
# capture is the whole visible screen, so earlier captures repeat its adds):
# the echoed `add N` inputs (at least two) and the last `total=N` line, which
# must equal their sum.
_tally_result() {
  local ev=$1 final facts
  facts=''
  final=''
  if [[ -n "$ev" && -d "$ev" ]]; then final=$(_final_capture "$ev"); fi
  if [[ -n "$final" ]]; then
    facts=$(awk '
      { gsub(/\r/, "") }
      /^[> ]*add +-?[0-9]+ *$/ { adds++; sum += $NF }
      /total=-?[0-9]+/ { match($0, /total=-?[0-9]+/); total = substr($0, RSTART + 6, RLENGTH - 6) + 0; have = 1 }
      END {
        if (adds >= 2) print "adds yes"; else print "adds no"
        if (have && adds >= 2 && total == sum) print "total matches"; else print "total differs"
      }' "$final")
  fi
  if printf '%s\n' "$facts" | grep -qx 'adds yes'; then
    _record PASS "final capture shows at least two add inputs"
  else
    _record FAIL "final capture shows at least two add inputs"
  fi
  if printf '%s\n' "$facts" | grep -qx 'total matches'; then
    _record PASS "final capture shows a total=N line equal to the sum of the adds"
  else
    _record FAIL "final capture shows a total=N line equal to the sum of the adds"
  fi
}

# The post-check starts a private tmux server and a scratch state directory.
# Both go away on normal exit, INT and TERM.
_TALLY_XDG=''
_tally_cleanup() {
  tmux -L sjujp-verify-tally kill-server 2>/dev/null || true
  if [[ -n "$_TALLY_XDG" ]]; then rm -rf "$_TALLY_XDG"; fi
  _TALLY_XDG=''
}

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
  local skill root drive ev
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
  _TALLY_XDG=$(mktemp -d)
  trap '_tally_cleanup' EXIT
  trap '_tally_cleanup; exit 130' INT
  trap '_tally_cleanup; exit 143' TERM
  command-succeeds "XDG_STATE_HOME='$_TALLY_XDG' '$skill/scripts/launch'"
  command-succeeds "XDG_STATE_HOME='$_TALLY_XDG' '$drive' > '$_TALLY_XDG/drive.out'"
  command-succeeds "XDG_STATE_HOME='$_TALLY_XDG' '$skill/scripts/cleanup'"
  command-succeeds "! tmux -L sjujp-verify-tally has-session -t tally"
  ev=''
  [[ -f "$_TALLY_XDG/drive.out" ]] && ev=$(tail -1 "$_TALLY_XDG/drive.out")
  command-succeeds "test -n '$ev' && find '$ev' -type f -size +0 | grep -q ."
  _tally_result "$ev"
  _tally_cleanup
  trap - EXIT INT TERM
}
