pre() {
    jj-repo
    jj-bookmark-exists main
    # Stack is one change, and it is NOT on top of main.
    jj-file-in-rev @- src/reports/csv-export.js
    not jj-file-in-rev @- CHANGELOG.md
    file-contains README.md 'Report Service'
    command-succeeds "jj log -r 'main' --no-graph -T 'description.first_line()' | grep -q 'Document changelog location'"
    command-succeeds "! jj log -r '@- & main::' --no-graph -T 'change_id' | grep -q ."
}

post() {
    # main now has the feature AND the teammate's change, and the feature
    # change descends from the old main.
    jj-file-in-rev main src/reports/csv-export.js
    command-succeeds "jj file show -r main README.md | grep -q 'See CHANGELOG.md'"
    command-succeeds "jj log -r 'main' --no-graph -T 'description.first_line()' | grep -q 'Add CSV export helper'"
    command-succeeds "jj log -r 'ancestors(main) & description(substring:\"Document changelog location\")' --no-graph -T 'change_id' | grep -q ."
    jj-count conflicts eq 0
    jj-count changes eq 0
}
