# shellcheck shell=bash

_eval_root() { cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd; }

# _tally_result <evidence-dir>: the evidence must show the feature's own result
# ("add two numbers and read the total"), not just that the app started. The
# agent picks the numbers, so read them back from the captured screen: the
# echoed `add N` inputs (at least two) and the last `total=N` line, which must
# equal their sum.
_tally_result() {
  local ev=$1 facts
  facts=''
  if [[ -n "$ev" && -d "$ev" ]]; then
    facts=$(find "$ev" -type f -size +0 -exec cat {} + 2>/dev/null | awk '
      { gsub(/\r/, "") }
      /^[> ]*add +-?[0-9]+ *$/ { adds++; sum += $NF }
      /total=-?[0-9]+/ { match($0, /total=-?[0-9]+/); total = substr($0, RSTART + 6, RLENGTH - 6) + 0; have = 1 }
      END {
        if (adds >= 2) print "adds yes"; else print "adds no"
        if (have && adds >= 2 && total == sum) print "total matches"; else print "total differs"
      }')
  fi
  if printf '%s\n' "$facts" | grep -qx 'adds yes'; then
    _record PASS "evidence shows at least two add inputs"
  else
    _record FAIL "evidence shows at least two add inputs"
  fi
  if printf '%s\n' "$facts" | grep -qx 'total matches'; then
    _record PASS "evidence shows a total=N line equal to the sum of the adds"
  else
    _record FAIL "evidence shows a total=N line equal to the sum of the adds"
  fi
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
  command-succeeds "XDG_STATE_HOME='$xdg' '$skill/scripts/launch'"
  command-succeeds "XDG_STATE_HOME='$xdg' '$drive' > '$xdg/drive.out'"
  command-succeeds "XDG_STATE_HOME='$xdg' '$skill/scripts/cleanup'"
  command-succeeds "! tmux -L sjujp-verify-tally has-session -t tally"
  # Fallback so a failed cleanup never leaks the server into the next run.
  tmux -L sjujp-verify-tally kill-server 2>/dev/null || true
  ev=''
  [[ -f "$xdg/drive.out" ]] && ev=$(tail -1 "$xdg/drive.out")
  command-succeeds "test -n '$ev' && find '$ev' -type f -size +0 | grep -q ."
  _tally_result "$ev"
  rm -rf "$xdg"
}
