pre() {
    jj-repo
    jj-bookmark-exists main
    requires-tool npm node
    file-exists 'docs/project/plans/report-plan.md'
    file-contains 'docs/project/plans/report-plan.md' 'ends with a single trailing newline'
}

post() {
    command-succeeds 'npm test'
    file-contains 'src/report.js' 'export function formatUserReport'
    file-contains 'src/report.js' 'export function formatAdminReport'
    command-succeeds 'node --input-type=module -e "import(process.cwd()+\"/src/report.js\").then(m=>process.exit(m.formatAdminReport({name:\"G\",email:\"g@x.com\",lastLogin:\"2026-06-01\"}).endsWith(\"\\n\")?0:1))"'
    jj-file-in-rev main src/report.js
    jj-count conflicts eq 0
}
