# Testing Sjujperpowers

Two kinds of tests:

- **`tests/`** — does the plugin's non-LLM code work? Bash, node, and python integration tests.
- **`evals/`** — does an agent follow the skills in a real session? Hand-run scenarios ported from upstream's Quorum lab; see `evals/README.md`.

## Plugin tests

Live in `tests/`. Currently:

- `tests/hooks/` — session-start hook.
- `tests/opencode/` — OpenCode plugin loading, bootstrap caching, and tool registration.
- `tests/pi/` — Pi extension.
- `tests/codex/` — Codex marketplace manifest.
- `tests/claude-code/` — SDD tests plus `test-sdd-workspace.sh` (requires `jj`).
- `tests/starting-a-change/` — `fresh-change`, `trunk-rev`, `add-workspace`: spec/plan stay in the working copy, loose WIP is never absorbed, trunk resolves without config, workspaces descend from a committed ignore entry (requires `jj`).
- `tests/systematic-debugging/` — find-polluter helper.
- `tests/writing-skills/` — skill graph rendering.
- `tests/shell-lint/` — shell lint.
- `tests/fork-rename/` — `scripts/fork-rename.mjs` (upstream-name transform used when syncing; see `docs/upstream-sync.md`).
- `tests/upstream-sync/` — the rebase step of `docs/upstream-sync.md`: preflight revset matches what `-s` moves, side branches off the stack survive with parent and diff intact.
- `tests/explicit-skill-requests/` — LLM evals (Haiku-specific, multi-turn, and skill-name-prompted).

Run plugin tests via the relevant directory's `run-*.sh` or `npm test`.

## Skill behavior evals

`evals/` holds a small set of scenarios ported from upstream's [superpowers-evals](https://github.com/prime-radiant-inc/superpowers-evals) to jj, without the Quorum harness: you build the fixture with `evals/run setup <scenario>`, play the human per `story.md` in the harness under test, then `evals/run post` for the deterministic backstop. Grading the acceptance criteria is manual. Details and the scenario list are in `evals/README.md`.
