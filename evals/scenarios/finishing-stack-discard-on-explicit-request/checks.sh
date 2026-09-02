pre() {
    jj-repo
    jj-bookmark-exists main
    jj-count changes eq 1
}

post() {
    # Discard confirmed: the stack is gone, main did not move, nothing landed.
    jj-count changes eq 0
    not jj-file-in-rev @ src/reports/csv-export.js
    not jj-file-in-rev main src/reports/csv-export.js
    file-contains README.md 'Report Service'
}
