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

# A git-ignored, untracked root hk.pkl is not the committed config.
ign="$TEST_ROOT/ignored"; mkdir -p "$ign"
(cd "$ign" && jj git init --colocate >/dev/null 2>&1 \
  && printf 'hk.pkl\n' > .gitignore && jj commit -m gitignore >/dev/null 2>&1 \
  && cp "$repo/hk.pkl" hk.pkl)
run bash -c "cd '$ign' && '$HK_CHECK'"
assert_eq "$code" "2" "untracked, git-ignored hk.pkl stops hk-check"

# Evidence records the run's own plan, not the un-narrowed one.
run bash -c "cd '$repo' && '$HK_CHECK' --evidence '$TEST_ROOT/ev2.json' --profile slow"
assert_eq "$code" "1" "evidence run with --profile slow still runs the committed steps"
assert_eq "$(jq -c '[.steps[] | {name, status}]' "$TEST_ROOT/ev2.json")" '[{"name":"real","status":"included"},{"name":"heavy","status":"included"}]' "evidence plan reflects --profile slow"
assert_eq "$(jq -c .args "$TEST_ROOT/ev2.json")" '["--profile","slow"]' "evidence records the forwarded args"

# hk exits 0 for an unknown step; hk-check must refuse instead.
run bash -c "cd '$repo' && '$HK_CHECK' --step nosuch"
assert_eq "$code" "2" "--step naming no plan step stops hk-check"

if [[ "$FAILURES" -gt 0 ]]; then
  echo "STATUS: FAILED ($FAILURES)"
  exit 1
fi
echo "STATUS: PASSED"
