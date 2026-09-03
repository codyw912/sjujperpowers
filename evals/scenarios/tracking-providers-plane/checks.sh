SPEC='docs/project/specs/2026-09-02-health-report-design.md'
PLAN='docs/project/plans/2026-09-02-health-report.md'

pre() {
  jj-repo
  jj-bookmark-exists main
  file-exists .sjujperpowers/config.json
  file-contains .sjujperpowers/config.json '"provider": "plane"'
  not file-exists docs/project/roadmap.md
  not file-exists "$SPEC"
  not file-exists "$PLAN"
}

post() {
  file-exists "$SPEC"
  file-contains "$SPEC" '^\*\*Outcome:\*\* plane:DEMO-12$'
  file-exists "$PLAN"
  file-contains "$PLAN" '^\*\*Source:\*\* plane:DEMO-12$'
  not file-exists docs/project/roadmap.md
  command-succeeds "! jj file list -r main | grep -qx -- '$SPEC'"
  command-succeeds "! jj file list -r main | grep -qx -- '$PLAN'"
}
