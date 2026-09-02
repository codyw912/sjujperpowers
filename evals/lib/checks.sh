#!/usr/bin/env bash
# Check verbs for sjujperpowers eval scenarios — a small jj-native subset of
# upstream superpowers-evals' prelude (src/checks/prelude.sh + fs-verbs.ts).
#
# Source this file, then call `run-checks pre|post <scenario-dir>` with cwd
# set to the fixture repo. Every verb records PASS/FAIL and returns 0 so a
# check script runs to completion; `run-checks` exits 1 if anything failed.
#
# Verbs (arguments as in upstream where the verb exists there):
#   file-exists <path>                 path exists
#   file-contains <path> <ERE>         grep -E matches
#   command-succeeds '<shell>'         bash -c exits 0
#   requires-tool <tool>...            each tool on PATH (else the scenario is indeterminate)
#   jj-repo                            cwd is inside a jj repo
#   jj-count <changes|workspaces|conflicts> <eq|ne|gt|gte|lt|lte> <n>
#        changes    = non-empty changes in trunk..@ (trunk from trunk-rev)
#        workspaces = `jj workspace list` rows
#        conflicts  = changes in trunk..@ with conflicts
#   jj-bookmark-exists <name>          local bookmark exists
#   jj-bookmark-at <name> <revset>     bookmark points at the same commit as revset
#   jj-described '<revset>'            every change in revset has a non-empty description
#   jj-file-in-rev <revset> <path>     path is in the tree of revset
#   not <verb> [args...]               inverts a verb
set -u

EVAL_FAILURES=0
EVAL_CHECKS=0

_record() { # <status> <label>
  EVAL_CHECKS=$((EVAL_CHECKS + 1))
  if [ "$1" = PASS ]; then echo "  [PASS] $2"; else echo "  [FAIL] $2"; EVAL_FAILURES=$((EVAL_FAILURES + 1)); fi
}
_assert() { # <label> <cmd...>   — runs cmd quietly, records
  local label=$1; shift
  if "$@" >/dev/null 2>&1; then _record PASS "$label"; else _record FAIL "$label"; fi
}

_trunk() {
  local here; here=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
  "$here/skills/starting-a-change/scripts/trunk-rev" 2>/dev/null | cut -d' ' -f1
}

_cmp() { # <actual> <op> <expected>
  case "$2" in
    eq) [ "$1" -eq "$3" ];; ne) [ "$1" -ne "$3" ];; gt) [ "$1" -gt "$3" ];;
    gte) [ "$1" -ge "$3" ];; lt) [ "$1" -lt "$3" ];; lte) [ "$1" -le "$3" ];;
    *) return 2;;
  esac
}

file-exists()      { _assert "file-exists $1" test -e "$1"; }
file-contains()    { _assert "file-contains $1 /$2/" grep -Eq -- "$2" "$1"; }
command-succeeds() { _assert "command-succeeds: $1" bash -c "$1"; }
requires-tool() {
  local t; for t in "$@"; do
    if ! command -v "$t" >/dev/null 2>&1; then echo "  [INDETERMINATE] missing tool: $t"; exit 2; fi
  done
}
jj-repo() { _assert "jj-repo" jj root; }

jj-count() { # <what> <op> <n>
  local what=$1 op=$2 n=$3 actual trunk
  case "$what" in
    changes)    trunk=$(_trunk); actual=$(jj log -r "($trunk..@) ~ empty()" --no-graph -T '"x\n"' 2>/dev/null | wc -l | tr -d ' ');;
    workspaces) actual=$(jj workspace list 2>/dev/null | wc -l | tr -d ' ');;
    conflicts)  trunk=$(_trunk); actual=$(jj log -r "($trunk..@) & conflicts()" --no-graph -T '"x\n"' 2>/dev/null | wc -l | tr -d ' ');;
    *) _record FAIL "jj-count: unknown subject $what"; return 0;;
  esac
  if _cmp "$actual" "$op" "$n"; then _record PASS "jj-count $what $op $n (actual $actual)"; else _record FAIL "jj-count $what $op $n (actual $actual)"; fi
}

jj-bookmark-exists() { _assert "jj-bookmark-exists $1" bash -c "jj log -r 'present(bookmarks(exact:\"$1\"))' --no-graph -T 'change_id' | grep -q ."; }
jj-bookmark-at() { # <name> <revset>
  local a b
  a=$(jj log -r "present(bookmarks(exact:\"$1\"))" --no-graph -T 'commit_id' 2>/dev/null)
  b=$(jj log -r "$2" --no-graph -T 'commit_id' 2>/dev/null)
  if [ -n "$a" ] && [ "$a" = "$b" ]; then _record PASS "jj-bookmark-at $1 $2"; else _record FAIL "jj-bookmark-at $1 $2 (bookmark=${a:-none} rev=${b:-none})"; fi
}
jj-described() { # <revset>
  local undesc
  undesc=$(jj log -r "($1) & description(exact:\"\")" --no-graph -T 'change_id.short() ++ "\n"' 2>/dev/null)
  if [ -z "$undesc" ]; then _record PASS "jj-described $1"; else _record FAIL "jj-described $1 (undescribed: $(echo "$undesc" | tr '\n' ' '))"; fi
}
jj-file-in-rev() { _assert "jj-file-in-rev $1 $2" bash -c "jj file list -r '$1' | grep -qx -- '$2'"; }

not() { # <verb> [args...]
  local before=$EVAL_FAILURES
  "$@" >/dev/null
  if [ "$EVAL_FAILURES" -gt "$before" ]; then EVAL_FAILURES=$before; _record PASS "not $*"; else _record FAIL "not $*"; fi
}

jj-file-anywhere() { # <path>  — path exists in the tree of some visible revision
  _assert "jj-file-anywhere $1" bash -c "for r in \$(jj log -r 'all()' --no-graph -T 'commit_id ++ \"\\n\"'); do jj file list -r \"\$r\" 2>/dev/null | grep -qx -- '$1' && exit 0; done; exit 1"
}
run-checks() { # <pre|post> <scenario-dir>
  local phase=$1 dir=$2
  # shellcheck disable=SC1091
  . "$dir/checks.sh"
  echo "$phase checks ($dir):"
  "$phase"
  echo "  $((EVAL_CHECKS - EVAL_FAILURES))/$EVAL_CHECKS passed"
  [ "$EVAL_FAILURES" -eq 0 ]
}
