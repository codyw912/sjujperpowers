# Testing Sjujperpowers

Two kinds of tests:

- **`tests/`** — does the plugin's non-LLM code work? Bash, node, and python integration tests.
- **`evals/`** — upstream LLM-session harness. Not vendored in this fork.

## Plugin tests

Live in `tests/`. Currently:

- `tests/hooks/` — session-start hook.
- `tests/opencode/` — OpenCode plugin loading, bootstrap caching, and tool registration.
- `tests/pi/` — Pi extension.
- `tests/codex/` — Codex marketplace manifest and plugin packaging.
- `tests/codex-plugin-sync/` — Codex plugin sync verification.
- `tests/claude-code/` — SDD tests plus `test-sdd-workspace.sh` (requires `jj`).
- `tests/starting-a-change/` — `fresh-change`, `trunk-rev`, `add-workspace`: spec/plan stay in the working copy, loose WIP is never absorbed, trunk resolves without config, workspaces descend from a committed ignore entry (requires `jj`).
- `tests/systematic-debugging/` — find-polluter helper.
- `tests/writing-skills/` — skill graph rendering.
- `tests/shell-lint/` — shell lint.
- `tests/explicit-skill-requests/` — LLM evals (Haiku-specific, multi-turn, and skill-name-prompted).

Run plugin tests via the relevant directory's `run-*.sh` or `npm test`.

## Skill behavior evals

The upstream `evals/` harness is not vendored. Plugin-infrastructure tests still live at `tests/`.
