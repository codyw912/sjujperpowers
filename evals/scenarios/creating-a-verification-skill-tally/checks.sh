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
  command-succeeds "XDG_STATE_HOME='$xdg' '$skill/scripts/launch'"
  command-succeeds "XDG_STATE_HOME='$xdg' '$drive' > '$xdg/drive.out'"
  command-succeeds "XDG_STATE_HOME='$xdg' '$skill/scripts/cleanup'"
  command-succeeds "! tmux -L sjujp-verify-tally has-session -t tally"
  # Fallback so a failed cleanup never leaks the server into the next run.
  tmux -L sjujp-verify-tally kill-server 2>/dev/null || true
  ev=''
  [[ -f "$xdg/drive.out" ]] && ev=$(tail -1 "$xdg/drive.out")
  command-succeeds "test -n '$ev' && find '$ev' -type f -size +0 | grep -q ."
  rm -rf "$xdg"
}
