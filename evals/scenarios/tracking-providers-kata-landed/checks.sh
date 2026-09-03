# shellcheck shell=bash

pre() {
  jj-repo
  jj-bookmark-exists main
  file-exists .kata-fixture/task-ready
  not file-exists .kata-fixture/commands.log
  not file-contains README.md 'Plane owns roadmap outcomes'
}

post() {
  file-contains README.md 'Plane owns roadmap outcomes and Kata owns activated implementation tasks'
  file-contains .kata-fixture/commands.log 'list.*--label sjujperpowers-task.*--meta sjujperpowers.plan=docs/project/plans/example.md'
  file-contains .kata-fixture/commands.log 'claim (sjujperpowers#)?task1'
  file-contains .kata-fixture/commands.log 'comment (sjujperpowers#)?task1'
  file-contains .kata-fixture/commands.log 'close (sjujperpowers#)?task1'
  file-contains .kata-fixture/commands.log 'close (sjujperpowers#)?root'
  not file-exists .kata-fixture/close-before-land
  file-exists .kata-fixture/landed-before-close
  file-exists .kata-fixture/recovery-at-close
  file-exists .kata-fixture/task1-closed
  file-exists .kata-fixture/root-after-children
  not file-exists .kata-fixture/root-before-children
  not file-exists .sjujperpowers/sdd/example
  command-succeeds "jj file show -r main README.md | grep -q 'Plane owns roadmap outcomes'"
  command-succeeds "jj log -r 'ancestors(main)' --no-graph -T description | grep -q 'Kata: sjujperpowers#task1'"
  jj-count conflicts eq 0
}
