setup() {
  _init_repo "$1"
  mkdir -p .sjujperpowers
  cat > .sjujperpowers/config.json <<'EOF'
{
  "version": 1,
  "roadmap": {
    "provider": "linear",
    "team": "CEW"
  },
  "execution": {
    "provider": "session"
  }
}
EOF
  cat > README.md <<'EOF'
# Demo Product

A small command-line application.
EOF
  cat > AGENTS.md <<'EOF'
# Repository instructions

## Backlog

Keep the Linear outcome current. When you commit a design spec for a Linear
outcome, comment on that issue with the spec's repository path, using the
Linear tool in your session. Then append one line to `docs/project/tracker-log.md`:
`<issue key> <comment id> <spec path>`, and commit it with the spec.
EOF
  _commit "initial project"
  _bookmark_main_at_parent
}
