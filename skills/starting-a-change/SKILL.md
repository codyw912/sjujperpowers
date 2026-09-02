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

## Step 1: Resolve tracking and claim

**REQUIRED SUB-SKILL:** Use sjujperpowers:tracking-providers.

Run its checked resolver before any issue or repository mutation. For `session` or `none`, continue to Step 2 unchanged.

For `kata`:

1. Read the configured project from normalized output.
2. If the user or caller supplied a child issue ref, validate with `kata --project <project> --json show <ref>` that it is open and labeled `sjujperpowers-task`; reject `sjujperpowers-plan` roots. A named-plan caller MUST first recover its mapping with tracking-providers, reconcile completed task numbers from its recovery ledger, and supply the lowest-numbered incomplete child; if it did not, stop rather than infer from open state. Only when neither a plan nor issue ref was supplied, run `kata --project <project> --json next --label sjujperpowers-task` and use `issue.short_id`; `issue: null` means stop with no ready task work.
3. Build the qualified ref as `<project>#<short_id>`.
4. Claim without force:

```bash
kata --project <project> --json claim <short_id>
```

Claim failure stops before `fresh-change`. Never select a replacement implicitly and never use `--force`.

## Step 2: Fresh change

Run this skill's `scripts/fresh-change`. It applies three rules and prints `<change-id> <mode>`:

| `@` is | It does | Why |
|--------|---------|-----|
| empty + undescribed | reuse it (`reused`) | the normal state right after `jj commit` — the spec/plan you just committed sit below it |
| described | `jj new` on top (`new-on-top`) | a described change is deliberate work; build on it |
| non-empty + undescribed | `jj new @-` (`new-beside-wip <id>`) | loose WIP stays in its own change beside yours, untouched |

Never `jj new trunk()` — that orphans the spec and plan committed above trunk. Never edit, squash, or abandon the user's change.

If the script warns that no trunk was found (a brand-new local repo: `trunk()` resolves to `root()` and there is no local `main`/`master`/`trunk` bookmark), relay the fix now so finishing works later: `jj bookmark create main -r <base>`. No config change is needed — `scripts/trunk-rev` resolves the trunk at runtime and every skill uses its output where it says `trunk()`.

## Step 3: Associate Kata work

Skip for `session` and `none`.

Immediately describe the fresh change with the issue title and qualified reference, then record the stable Jujutsu change ID:

```bash
jj describe -m "<issue title>

Kata: <project>#<short_id>"
CHANGE_ID="$(jj log -r @ --no-graph -T 'change_id')"
kata --project <project> --json comment <short_id> \
  --body "Associated Jujutsu change: $CHANGE_ID"
```

If fresh-change or association fails after the claim, add a substantive Kata comment describing the failed association and leave the visible claim for deliberate recovery. Do not hide it by selecting different work.

Report the change ID, fresh-change mode, and qualified Kata ref.

## Step 4: Separate working directory (only on request)

Skip unless the user explicitly asks or a declared preference requires it.

1. `jj workspace list` — if already in a named workspace for this work, skip creation.
2. Run this skill's `scripts/add-workspace <name>`. It adds `.workspaces/` to `.gitignore` if missing and commits that edit by fileset first (jj auto-tracks every new file, and the workspace's change must descend from the ignore entry), then `jj workspace add .workspaces/<name> -r @-` — a sibling of the fresh change on the same parent — and prints `<path> <change-id>`.
3. Work in that path. Report its change ID.

## Step 5: Project Setup

```bash
if [ -f package.json ]; then npm install; fi
if [ -f Cargo.toml ]; then cargo build; fi
if [ -f pyproject.toml ]; then uv sync; elif [ -f requirements.txt ]; then uv venv && uv pip install -r requirements.txt; fi
if [ -f go.mod ]; then go mod download; fi
```

## Step 6: Verify Clean Baseline

Run the project's baseline suite (`npm test` / `cargo test` / `pytest` / `go test ./...`).

If tests fail, report the failures and ask whether to proceed or investigate. For Kata-backed work, also comment on the claimed issue with the failing command and summary; do not close or silently release it. If tests pass:

```
Change <change-id> (<mode>) at <path>
Tests passing (<N> tests, 0 failures)
Ready to implement <feature-name>
```

## Quick Reference

| Situation | Action |
|-----------|--------|
| `jj root` fails | Stop with the contract message |
| Kata preflight fails | Stop before claim or repository mutation |
| Kata claim conflicts | Report the owner; never force or select a replacement |
| `@` empty + undescribed | Reuse `@` |
| `@` described | `jj new` on top |
| `@` non-empty + undescribed (loose WIP) | `jj new @-` — sibling, WIP untouched |
| No trunk found | Relay `jj bookmark create main -r <base>` |
| User asks for a separate directory | Ignore `.workspaces/`, then `jj workspace add` |
| Already in a named workspace | Skip `workspace add` |
| Tests fail at baseline | Report + ask; comment on a claimed Kata issue |

## Common Rationalizations

| Excuse | Reality |
|--------|---------|
| "I'm obviously on a clean change" | Run the script. Non-empty undescribed `@` is someone's WIP; stacking on it absorbs it. |
| "`jj new trunk()` gives the cleanest start" | It orphans the spec and plan committed above trunk. Stay on the stack; step beside WIP only. |
| "The workspace dir is surely ignored" | Grep `.gitignore`. An unignored workspace directory is snapshotted. |
| "Baseline tests can wait" | A dirty baseline makes every later failure ambiguous. Run them now. |
