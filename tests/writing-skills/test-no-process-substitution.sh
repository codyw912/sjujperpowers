#!/usr/bin/env bash
# Skill code blocks are run by agents through harness shell tools. Process
# substitution (`< <(...)`) hung Oh My Pi's bash tool until its 300-second
# timeout, so no fenced code block in a skill may use it. Prose may still
# name the form when it warns against it.
#
# Usage: test-no-process-substitution.sh [REPO_ROOT]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "${1:-$SCRIPT_DIR/../..}" && pwd)"

# A fence opens on a run of 3+ backticks or tildes and closes only on a run of
# the same character, at least as long, followed by nothing but whitespace
# (CommonMark). Every other line inside is content, and is scanned, so a
# shorter or different fence line in a nested example does not end the block.
hits=$(find "$REPO_ROOT/skills" -name '*.md' -type f -print0 \
  | xargs -0 awk '
      FNR == 1 { fch = ""; flen = 0 }
      {
        if (match($0, /^[[:space:]]*(```+|~~~+)/)) {
          run = substr($0, RSTART, RLENGTH)
          sub(/^[[:space:]]*/, "", run)
          ch = substr(run, 1, 1)
          len = length(run)
          rest = substr($0, RLENGTH + 1)
          if (fch == "") {
            if (!(ch == "`" && rest ~ /`/)) { fch = ch; flen = len; next }
          } else if (ch == fch && len >= flen && rest ~ /^[[:space:]]*$/) {
            fch = ""; flen = 0; next
          }
        }
        if (fch != "" && $0 ~ /<[[:space:]]*<\(/) print FILENAME ":" FNR ": " $0
      }
    ')

if [[ -n "$hits" ]]; then
  echo "  [FAIL] process substitution in skill code blocks:"
  printf '%s\n' "${hits//$REPO_ROOT\//}" | sed 's/^/    /'
  exit 1
fi
echo "  [PASS] no process substitution in skill code blocks"
