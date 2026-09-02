setup() {
  _init_repo "$1"
  mkdir -p .sjujperpowers
  cat > .sjujperpowers/config.json <<'EOF'
{
  "version": 1,
  "roadmap": {
    "provider": "plane",
    "project": "Demo Product"
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
  _commit "initial project"
  _bookmark_main_at_parent
}
