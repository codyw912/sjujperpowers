# shellcheck shell=bash
# Drive one evals/scenarios/<scenario> through a headless omp agent inside the
# `sjujperpowers` tmux session that scripts/launch started.
#
#   scenario_prepare <scenario>       build the fixture; point omp at this
#                                     checkout's skills/; open the evidence dir
#   scenario_turn <n> <message>       one omp -p turn (continuing the session)
#   scenario_post                     run the scenario's post-checks, check that
#                                     the agent loaded skills from this checkout
#   scenario_finish                   tear the fixture down; print the evidence dir
#
# Every command runs in the tmux pane, so the screen captures in the evidence
# directory show exactly what ran. The fixture and the agent's session live
# outside the repository; nothing here writes into the working copy.

here=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
root=$(cd "$here/../../../.." && pwd)
tty="$here/lib/tmux-tty.sh"
name=sjujperpowers

# One pane command; waits for its own marker and captures the screen.
_pane() { # <label> <timeout-seconds> <command>
  local label=$1 seconds=$2 cmd=$3
  "$tty" send "$name" "clear; $cmd; echo \"__${label}_DONE rc=\$?\""
  "$tty" wait "$name" "__${label}_DONE rc=[0-9]+" "$seconds"
  "$tty" capture "$name" "$EVIDENCE/$label.txt"
  grep -Eq "__${label}_DONE rc=0" "$EVIDENCE/$label.txt"
}

scenario_prepare() { # <scenario>
  SCENARIO=$1
  EVIDENCE=$("$tty" evidence-dir "$name")
  RUN="$EVIDENCE/run"
  mkdir -p "$RUN/sessions"
  "$root/evals/run" setup "$SCENARIO" > "$EVIDENCE/setup.txt" 2>&1
  FIXTURE=$(sed -n 's/^  cd //p' "$EVIDENCE/setup.txt" | tail -1)
  [ -d "$FIXTURE/.git" ] || { echo "setup did not print a colocated fixture" >&2; return 1; }
  # The agent loads this checkout's skills, not an installed copy, and runs
  # without the advisor so the transcript is the agent's own work.
  mkdir -p "$FIXTURE/.omp"
  printf 'skills:\n  customDirectories:\n    - %s\n' "$root/skills" > "$FIXTURE/.omp/config.yml"
  printf 'advisor:\n  enabled: false\n' > "$RUN/no-advisor.yml"
  echo '.omp/' >> "$FIXTURE/.git/info/exclude"
  printf 'scenario=%s\nfixture=%s\nskills=%s\nhead=%s\n' "$SCENARIO" "$FIXTURE" "$root/skills" \
    "$(cd "$root" && jj log -r @ --no-graph -T 'commit_id' 2>/dev/null)" > "$EVIDENCE/meta.txt"
  _pane setup 30 "cd '$FIXTURE' && jj st"
}

scenario_turn() { # <n> <message>
  local n=$1 msg=$2 cont=""
  printf '%s\n' "$msg" > "$RUN/turn-$n.msg"
  [ "$n" -gt 1 ] && cont="-c"
  _pane "turn$n" 1500 "omp -p --no-extensions --auto-approve --config '$RUN/no-advisor.yml' --session-dir '$RUN/sessions' $cont \"\$(cat '$RUN/turn-$n.msg')\" > '$EVIDENCE/turn-$n.txt' 2>&1; tail -25 '$EVIDENCE/turn-$n.txt'"
}

scenario_post() {
  # The agent must have loaded at least one skill from this checkout.
  _pane provenance 30 "grep -h -o 'Skill file: $root/skills/[^]]*' '$RUN'/sessions/*.jsonl | sort -u | tee '$EVIDENCE/skills-loaded.txt' | grep -q ."
  _pane post 120 "'$root/evals/run' post '$SCENARIO' '$FIXTURE'"
}

scenario_finish() {
  [ -n "${FIXTURE:-}" ] && "$root/evals/run" teardown "$FIXTURE" >/dev/null 2>&1 || true
  printf '%s\n' "$EVIDENCE"
}
