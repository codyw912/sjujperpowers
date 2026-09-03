pre() {
    jj-repo
    jj-bookmark-exists main
    requires-tool npm node
    file-exists 'docs/project/plans/metrics-plan.md'
    file-exists '.sjujperpowers/sdd/metrics-plan/progress.md'
    file-contains '.sjujperpowers/sdd/metrics-plan/progress.md' '^# SDD ledger — plan: docs/project/plans/metrics-plan.md'
    file-contains '.sjujperpowers/sdd/metrics-plan/progress.md' 'fix round 1/5'
    not file-contains '.sjujperpowers/sdd/metrics-plan/progress.md' 'fix round 2'
    file-exists '.sjujperpowers/sdd/metrics-plan/task-2-brief.md'
    file-exists '.sjujperpowers/sdd/metrics-plan/task-2-report.md'
    file-exists '.sjujperpowers/sdd/metrics-plan/review-round1.diff'
    not file-exists 'src/summary.js'
    command-succeeds '! jj status | grep -q "^[AMD] "'
}

post() {
    command-succeeds 'npm test'
    not file-contains 'src/duration.js' 'seconds / 3600'
    command-succeeds 'test "$(grep -c padStart src/duration.js)" -le 1'
    file-contains '.sjujperpowers/sdd/metrics-plan/progress.md' 'Task 2: complete'
    file-exists 'src/summary.js'
    jj-file-in-rev main src/summary.js
    jj-count conflicts eq 0
}
