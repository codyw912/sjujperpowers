setup() {
  _init_repo "$1"
  mkdir -p .sjujperpowers
  cat > .sjujperpowers/config.json <<'JSON'
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
JSON
  cat > README.md <<'MD'
# Demo Product

A small command-line application.
MD
  _commit "initial project"
  _bookmark_main_at_parent
}
