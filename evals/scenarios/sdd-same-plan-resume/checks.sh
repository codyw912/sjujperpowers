pre() {
    jj-repo
    jj-bookmark-exists main
    requires-tool npm node
    file-exists 'docs/sjujperpowers/plans/2026-07-15-report-export.md'
    file-exists '.sjujperpowers/sdd/2026-07-15-report-export/progress.md'
    file-contains '.sjujperpowers/sdd/2026-07-15-report-export/progress.md' 'SDD ledger'
    file-contains '.sjujperpowers/sdd/2026-07-15-report-export/progress.md' 'Task 1: complete'
    file-exists 'src/export-csv.js'
    command-succeeds 'npm test'
}

post() {
    file-contains 'src/export-json.js' 'export function toJson'
    command-succeeds 'npm test'
    file-contains '.sjujperpowers/sdd/2026-07-15-report-export/progress.md' 'Task 2: complete'
    jj-file-in-rev main src/export-json.js
    command-succeeds 'test "$(jj log -r "all()" --no-graph -T "description.first_line() ++ \"\\n\"" | grep -c toCsv)" -eq 1'
    jj-count conflicts eq 0
}
