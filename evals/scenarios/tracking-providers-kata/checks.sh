# shellcheck shell=bash

pre() {
  jj-repo
  jj-bookmark-exists main
  file-exists .sjujperpowers/config.json
  file-exists .test-bin/kata
  not file-exists .kata-fixture/commands.log
  file-exists .kata-fixture/task-ready
  not file-contains README.md 'Plane owns roadmap outcomes'
}

post() {
  file-contains README.md 'Plane owns roadmap outcomes and Kata owns activated implementation tasks'
  file-exists .kata-fixture/commands.log
  file-contains .kata-fixture/commands.log 'list.*--label sjujperpowers-task.*--meta sjujperpowers.plan=docs/project/plans/example.md'
  file-contains .kata-fixture/commands.log 'claim (sjujperpowers#)?task1'
  file-contains .kata-fixture/commands.log 'comment (sjujperpowers#)?task1'
  not file-contains .kata-fixture/commands.log 'close '
  file-exists .sjujperpowers/sdd/example/progress.md
  command-succeeds "! jj file show -r main README.md | grep -q 'Plane owns roadmap outcomes'"
  file-exists .kata-fixture/change-at-claim
  file-exists .kata-fixture/description-at-claim
  command-succeeds 'test ! -s .kata-fixture/description-at-claim'
  command-succeeds "jj log -r 'ancestors(@)' --no-graph -T description | grep -q 'Kata: sjujperpowers#task1'"
  # shellcheck disable=SC2016
  command-succeeds 'id=$(cat .kata-fixture/change-at-claim); test -n "$(jj log -r "ancestors(@) & change_id($id)" --no-graph -T commit_id)"'
  jj-count conflicts eq 0
}
