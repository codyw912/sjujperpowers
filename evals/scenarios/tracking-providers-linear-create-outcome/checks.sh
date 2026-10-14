SPEC='docs/project/specs/2026-09-02-health-report-design.md'

pre() {
  jj-repo
  jj-bookmark-exists main
  file-contains .sjujperpowers/config.json '"provider": "linear"'
  not file-exists AGENTS.md
  not file-exists "$SPEC"
}

post() {
  file-exists "$SPEC"
  file-contains "$SPEC" '^\*\*Outcome:\*\* linear:CEW-[0-9]+$'
  # Committed above main, not left as loose work in @ and not landed.
  command-succeeds "jj diff --from main --to @- --name-only | grep -qx -- '$SPEC'"
  command-succeeds "! jj file list -r main | grep -qx -- '$SPEC'"
  command-succeeds "! ls docs/project/plans/*.md >/dev/null 2>&1"
  not file-exists docs/project/roadmap.md
}
