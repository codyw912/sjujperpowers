LOG='docs/project/tracker-log.md'

pre() {
  jj-repo
  jj-bookmark-exists main
  file-contains .sjujperpowers/config.json '"project": "Sjujperpowers"'
  file-contains AGENTS.md 'consult only this repository'
  not file-exists "$LOG"
}

post() {
  file-exists "$LOG"
  file-contains "$LOG" '^discovery CEW Sjujperpowers CEW-[1-9][0-9]*$'
  command-succeeds "[ \"\$(grep -c '^discovery ' '$LOG')\" = 1 ]"
  not file-exists docs/project/roadmap.md
}
