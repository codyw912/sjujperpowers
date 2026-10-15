---
name: verify-sjujperpowers
description: Use when verifying sjujperpowers behavior, when verifying-by-risk needs behavior evidence for a sjujperpowers stack, or when checking that the lifecycle skills still drive an agent correctly after a skill change
---

# Verify sjujperpowers

sjujperpowers' user-facing features are its lifecycle skills as an agent experiences them. Each drive script builds an `evals/scenarios/` fixture, runs a headless `omp -p` agent in it with **this checkout's** `skills/`, plays the scenario's human, runs the scenario's post-checks, and leaves the screens and transcripts as evidence.

## Launch

`scripts/launch` starts a private tmux session `sjujperpowers` (a bare bash pane at the repository root). Every drive command runs in that pane so the captures show what ran.

## Doctor

`scripts/doctor` before anything else. It checks `tmux`, `jj`, `omp`, `node`, that `omp -p` answers with the configured model, and that the `linear` MCP server is configured. Exit non-zero prints the fix. Run inside the dev shell (`devenv shell .agents/skills/verify-sjujperpowers/scripts/doctor`) or with those tools on PATH.

## Drive

One script per feature case. Each prints its evidence directory as its last line and exits non-zero when a step's result does not appear.

| Script | Feature | Notes |
|---|---|---|
| `scripts/drive-outcome-ask` | [tracker-outcomes.md](features/tracker-outcomes.md), case 1 | ~30 s; no tracker writes |
| `scripts/drive-outcome-create` | [tracker-outcomes.md](features/tracker-outcomes.md), case 2 | ~2 min; creates one `[eval scratch]` Linear issue in CEW |
| `scripts/drive-finishing-menu` | [finishing-a-change-stack.md](features/finishing-a-change-stack.md) | ~1 min |
| `scripts/drive-risk-brief` | [verifying-by-risk.md](features/verifying-by-risk.md) | several minutes |

Pick the cases whose skills the stack changes; for a stack touching `skills/**` broadly, run all four. A full run:

```bash
scripts/doctor && scripts/launch && scripts/drive-outcome-ask; rc=$?
scripts/cleanup; crc=$?; [ "$rc" -ne 0 ] || rc=$crc
echo "exit status: $rc"; [ "$rc" -eq 0 ]
```

Run `launch` and `cleanup` around each drive script; the drives share the one session name.

## Evidence

`$XDG_STATE_HOME/sjujperpowers/evidence/sjujperpowers/<UTC time>-<pid>/` (default `~/.local/state/…`), outside the repository:

- `meta.txt` — scenario, fixture path, skills directory, and the checkout's `@` commit at drive time.
- `turn-<n>.txt` — the agent's full output for each turn; `turn<n>.txt` — the pane capture.
- `skills-loaded.txt` — every `SKILL.md` the agent read; all must be under this checkout's `skills/`. An empty file fails the drive.
- `post.txt` — the scenario's post-checks (the last capture; judge this file).
- `run/sessions/` — the agent's session log, for tool-call inspection.

The scripts check what can be checked deterministically. Each feature file names what to read in the transcripts by hand.

## Cleanup

`scripts/cleanup` stops the tmux server; safe to run twice. Each drive tears its fixture down on exit, pass or fail. Linear scratch issues from `drive-outcome-create` persist; archive them in Linear.

## Helpers

`scripts/lib/tmux-tty.sh` (copied unchanged from creating-a-verification-skill): `start`, `send`, `keys`, `wait`, `capture`, `stop`, `evidence-dir`.

`scripts/lib/scenario.sh` (sourced by the drives): `scenario_prepare <scenario>`, `scenario_turn <n> <message>`, `scenario_post`, `scenario_finish`.
