# sjujperpowers

Personal fork of [obra/superpowers](https://github.com/obra/superpowers). Skills are Jujutsu-native, support independent roadmap and execution providers, and run on Claude Code, Oh My Pi, Pi, Codex, and OpenCode.

## jj-only

Skills never emit git commands. If `jj root` fails, the skill stops:

> This isn't a jj repo. Run `jj git init --colocate` and re-run, or tell me to continue without VCS steps.

Work starts on a fresh change via `starting-a-change`'s `scripts/fresh-change` (reuse an empty `@`, `jj new` on described work, `jj new @-` beside loose WIP — never `jj new trunk()`, which orphans the spec/plan stack). Artifacts (roadmap, spec, plan) are committed by fileset: `jj commit <path> -m …`. Ledgers record change IDs; review boundaries (SDD BASE / FIX_BASE) record commit IDs, which stay valid after rewrites. Do not emit `jj git push`, bookmark moves on `main`/`trunk()`, or `jj abandon` except inside finishing-a-change-stack's explicit user-chosen options.

jj's built-in `trunk()` only sees remote bookmarks and is `root()` in a local-only repo. Skills that need a real trunk (finishing, SDD final review) resolve it at runtime with `starting-a-change`'s `scripts/trunk-rev` (prefers `main@origin`, then the built-in when it carries a main/master/trunk label, then a local `main`/`master`/`trunk`); no repo config write is required or attempted. In this repo the built-in flips to `main@upstream` whenever upstream is newer — see `docs/upstream-sync.md`.

## Tracking and artifact layout

- Provider policy: `.sjujperpowers/config.json` when repository defaults are overridden
- File roadmap: `docs/project/roadmap.md`
- Specs: `docs/project/specs/YYYY-MM-DD-<topic>-design.md`
- Plans: `docs/project/plans/YYYY-MM-DD-<feature>.md`

Roadmap and execution providers are independent. Absent configuration preserves `file` roadmap plus `session` execution. File-roadmap specs carry `**Milestone:** M<N> — <title>` or `**Milestone:** none (unplanned)`; Plane-backed specs carry `**Outcome:** plane:<identifier>`; bootstrap/none specs carry `**Outcome:** none (bootstrap)`. Every plan carries a provider-neutral `**Source:**` copied or derived from that approved spec (`file:…`, `plane:…`, or `none (bootstrap)`).

The artifact hierarchy is external outcome or file milestone → spec → plan → numbered task. With Kata execution, the materialized plan root is not executable: roots carry `sjujperpowers-plan`, children carry `sjujperpowers-task`, every child blocks its root, and automatic selection filters for the child label.

## Testing

See [docs/testing.md](docs/testing.md).

## Editing skills

When editing a skill, use `sjujperpowers:writing-skills`.

## Bootstrap

A fresh session must be told to use skills before any other response. Check: open a clean session, say "Let's make a react todo list", and `brainstorming` should fire before code. If it does not, `using-sjujperpowers` is not loaded.

## Syncing upstream

See [docs/upstream-sync.md](docs/upstream-sync.md). The fork stack is `fork-base..main`; rebase its root onto `main@upstream`, move `fork-base`, resolve, then run `scripts/fork-rename.mjs` and the audit greps.
