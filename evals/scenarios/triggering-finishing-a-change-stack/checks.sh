pre() {
    jj-repo
    jj-bookmark-exists main
    jj-count changes eq 1
}

post() {
    jj-count changes eq 1
    not jj-bookmark-at main @-
    jj-file-in-rev @- src/reports/csv-export.js
}
