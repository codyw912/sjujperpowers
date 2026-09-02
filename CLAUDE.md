# sjujperpowers

Personal fork of [obra/superpowers](https://github.com/obra/superpowers). Skills are Jujutsu-native, there is a light roadmap layer, and the supported harnesses are Claude Code, Oh My Pi, Pi, Codex, and OpenCode.

## jj-only

Skills never emit git commands. If `jj root` fails, the skill stops:

> This isn't a jj repo. Run `jj git init --colocate` and re-run, or tell me to continue without VCS steps.

Work starts on a fresh change via `starting-a-change`'s `scripts/fresh-change` (reuse an empty `@`, `jj new` on described work, `jj new @-` beside loose WIP — never `jj new trunk()`, which orphans the spec/plan stack). Artifacts (roadmap, spec, plan) are committed by fileset: `jj commit <path> -m …`. Ledgers record change IDs; review boundaries (SDD BASE / FIX_BASE) record commit IDs, which stay valid after rewrites. Do not emit `jj git push`, bookmark moves on `main`/`trunk()`, or `jj abandon` except inside finishing-a-change-stack's explicit user-chosen options.

jj's built-in `trunk()` only sees remote bookmarks and is `root()` in a local-only repo. Skills that need a real trunk (finishing, SDD final review) resolve it at runtime with `starting-a-change`'s `scripts/trunk-rev` (prefers the built-in, else local `main`/`master`/`trunk`); no repo config write is required or attempted.

## Roadmap layout

- Roadmap: `docs/sjujperpowers/roadmap.md`
- Specs: `docs/sjujperpowers/specs/YYYY-MM-DD-<topic>-design.md`
- Plans: `docs/sjujperpowers/plans/YYYY-MM-DD-<feature>.md`

Hierarchy: roadmap milestone → spec → plan → task. Spec and plan headers carry `**Milestone:** M<N> — <title>` or `**Milestone:** none (unplanned)`.

## Testing

See [docs/testing.md](docs/testing.md).

## Editing skills

When editing a skill, use `sjujperpowers:writing-skills`.

## Bootstrap

A fresh session must be told to use skills before any other response. Check: open a clean session, say "Let's make a react todo list", and `brainstorming` should fire before code. If it does not, `using-sjujperpowers` is not loaded.
