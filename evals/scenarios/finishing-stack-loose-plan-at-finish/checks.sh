PLAN='docs/project/plans/2026-08-04-csv-export-rollout.md'

pre() {
    jj-repo
    jj-bookmark-exists main
    # Feature change plus the non-empty @ holding the loose plan.
    jj-count changes eq 2
    file-exists "$PLAN"
    jj-file-in-rev @- src/reports/csv-export.js
    not jj-file-in-rev @- "$PLAN"
}

post() {
    # Landed: main moved onto a change that has the feature...
    jj-file-in-rev main src/reports/csv-export.js
    # ...but NOT the plan.
    not jj-file-in-rev main "$PLAN"
    # The plan survived in some visible revision (working copy or a side change).
    jj-file-anywhere "$PLAN"
    jj-count conflicts eq 0
}
