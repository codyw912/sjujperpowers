SPEC='docs/project/specs/2026-09-02-health-report-design.md'
LOG='docs/project/tracker-log.md'

pre() {
  jj-repo
  jj-bookmark-exists main
  file-contains .sjujperpowers/config.json '"provider": "linear"'
  file-contains AGENTS.md 'comment on that issue'
  not file-exists "$SPEC"
  not file-exists "$LOG"
}

post() {
  file-exists "$SPEC"
  file-contains "$SPEC" '^\*\*Outcome:\*\* linear:CEW-7$'
  file-contains "$LOG" "^CEW-7 [0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12} $SPEC\$"
  not file-exists docs/project/roadmap.md
  command-succeeds "! jj file list -r main | grep -qx -- '$SPEC'"
}
