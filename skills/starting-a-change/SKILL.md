---
name: starting-a-change
description: Use when starting feature work or before executing an implementation plan - puts the work on a fresh jj change on trunk so nothing in flight gets absorbed
---

# Starting a Change

## Overview

Put work on a fresh jj change without absorbing anything in flight. Isolation is a change, not a directory. The stack you build on (`trunk()..@` — roadmap, spec, plan commits) stays in the working copy; only loose, undescribed WIP is kept out.

**Announce at start:** "I'm using the starting-a-change skill to put this work on a fresh jj change."

## Step 0: Confirm jj repo

Run `jj root`. If it fails, stop:

> This isn't a jj repo. Run `jj git init --colocate` and re-run, or tell me to continue without VCS steps.

## Step 1: Fresh change

Run this skill's `scripts/fresh-change`. It applies three rules and prints `<change-id> <mode>`:

| `@` is | It does | Why |
|--------|---------|-----|
| empty + undescribed | reuse it (`reused`) | the normal state right after `jj commit` — the spec/plan you just committed sit below it |
| described | `jj new` on top (`new-on-top`) | a described change is deliberate work; build on it |
| non-empty + undescribed | `jj new @-` (`new-beside-wip <id>`) | loose WIP stays in its own change beside yours, untouched |

Never `jj new trunk()` — that orphans the spec and plan committed above trunk. Never edit, squash, or abandon the user's change.

If the script warns that no trunk was found (a brand-new local repo: `trunk()` resolves to `root()` and there is no local `main`/`master`/`trunk` bookmark), relay the fix now so finishing works later: `jj bookmark create main -r <base>`. No config change is needed — `scripts/trunk-rev` resolves the trunk at runtime and every skill uses its output where it says `trunk()`.

Report the change ID and mode.

## Step 2: Separate working directory (only on request)

Skip unless the user explicitly asks or a declared preference requires it.

1. `jj workspace list` — if already in a named workspace for this work, skip creation.
2. Run this skill's `scripts/add-workspace <name>`. It adds `.workspaces/` to `.gitignore` if missing and commits that edit by fileset first (jj auto-tracks every new file, and the workspace's change must descend from the ignore entry), then `jj workspace add .workspaces/<name> -r @-` — a sibling of the fresh change on the same parent — and prints `<path> <change-id>`.
3. Work in that path. Report its change ID.

## Step 3: Project Setup

```bash
if [ -f package.json ]; then npm install; fi
if [ -f Cargo.toml ]; then cargo build; fi
if [ -f pyproject.toml ]; then uv sync; elif [ -f requirements.txt ]; then uv venv && uv pip install -r requirements.txt; fi
if [ -f go.mod ]; then go mod download; fi
```

## Step 4: Verify Clean Baseline

Run `npm test` / `cargo test` / `pytest` / `go test ./...`.

**If tests fail:** Report failures, ask whether to proceed or investigate. **If tests pass:** Report ready.

```
Change <change-id> (<mode>) at <path>
Tests passing (<N> tests, 0 failures)
Ready to implement <feature-name>
```

## Quick Reference

| Situation | Action |
|-----------|--------|
| `jj root` fails | Stop with the contract message |
| `@` empty + undescribed | Reuse `@` |
| `@` described | `jj new` on top |
| `@` non-empty + undescribed (loose WIP) | `jj new @-` — sibling, WIP untouched |
| No trunk found | Relay `jj bookmark create main -r <base>` |
| User asks for a separate directory | Ignore `.workspaces/`, then `jj workspace add` |
| Already in a named workspace | Skip `workspace add` |
| Tests fail at baseline | Report + ask |

## Common Rationalizations

| Excuse | Reality |
|--------|---------|
| "I'm obviously on a clean change" | Run the script. Non-empty undescribed `@` is someone's WIP; stacking on it absorbs it. |
| "`jj new trunk()` gives the cleanest start" | It orphans the spec and plan committed above trunk. Stay on the stack; step beside WIP only. |
| "The workspace dir is surely ignored" | Grep `.gitignore`. An unignored workspace directory is snapshotted. |
| "Baseline tests can wait" | A dirty baseline makes every later failure ambiguous. Run them now. |
