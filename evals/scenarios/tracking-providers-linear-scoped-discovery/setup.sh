setup() {
  _init_repo "$1"
  mkdir -p .sjujperpowers
  cat > .sjujperpowers/config.json <<'EOF2'
{
  "version": 1,
  "roadmap": {
    "provider": "linear",
    "team": "CEW",
    "project": "Sjujperpowers"
  },
  "execution": {
    "provider": "session"
  }
}
EOF2
  cat > README.md <<'EOF2'
# Demo Product

A small command-line application.
EOF2
  cat > AGENTS.md <<'EOF2'
# Repository instructions

## Backlog

This repository's work is tracked in Linear. When you choose a next task from
the backlog, consult only this repository's project and record the scope you
used by appending one line to `docs/project/tracker-log.md`:
`discovery <team key> <project name> <picked issue key>`. Commit that line.
EOF2
  _commit "initial project"
  _bookmark_main_at_parent
}
