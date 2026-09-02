pre() {
    jj-repo
    jj-bookmark-exists main
    jj-count changes eq 1
    jj-file-in-rev @- src/reports/csv-export.js
}

post() {
    # Human chose "keep as-is": the stack must be exactly what it was and
    # main must not have moved.
    jj-count changes eq 1
    jj-count conflicts eq 0
    jj-file-in-rev @- src/reports/csv-export.js
    not jj-bookmark-at main @-
    jj-described 'main..@-'
}
