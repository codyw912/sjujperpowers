#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$repo_root"

if git check-ignore -q .sjujperpowers/config.json; then
  echo '.sjujperpowers/config.json must be trackable' >&2
  exit 1
fi

git check-ignore -q .sjujperpowers/sdd/example/progress.md

echo 'tracking provider config ignore rules: pass'
