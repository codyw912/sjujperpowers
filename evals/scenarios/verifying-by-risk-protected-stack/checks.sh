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
