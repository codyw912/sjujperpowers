---
name: finishing-a-change-stack
description: Use when implementation is complete, all tests pass, and you need to decide how to land a jj change stack
---

# Finishing a Change Stack

## Overview

**Core principle:** Preflight providers → Verify tests → Record evidence → Update the roadmap → Show and shape the stack → Present options → Execute choice → Finalize provider state → Clean up.

**Announce at start:** "I'm using the finishing-a-change-stack skill to complete this work."

If `jj root` fails, stop: "This isn't a jj repo. Run `jj git init --colocate` and re-run, or tell me to continue without VCS steps."

## Step 0: Resolve Tracking

**REQUIRED SUB-SKILL:** Use sjujperpowers:tracking-providers.

Run its checked resolver before any roadmap, issue, or repository mutation. Retain the plan path, source, configured completion event, Kata parent/child refs, stable Jujutsu change IDs, and SDD recovery-workspace path supplied by the execution skill. A Kata preflight failure stops before completion bookkeeping.

## Step 1: Verify Tests

Run the project's full test suite (`npm test` / `cargo test` / `pytest` / `go test ./...`).

**If tests fail**, report the failures and stop — the menu comes after a green suite:

```
Tests failing (<N> failures). Must fix before completing:

[Show failures]
```

**If tests pass:** for Kata, comment on each implemented child with its issue-specific verified scope, exact command and result, and stable Jujutsu change ID. This records evidence but MUST NOT close anything. Continue to Step 2.

## Step 2: Update the Roadmap

Branch on the resolved roadmap provider:

For the `file` provider, use `docsRoot` from the normalized configuration for the roadmap path. `docs/project` below is only the default.

- `file`: if `docs/project/roadmap.md` is absent, skip. Otherwise ensure the plan path appears under its source milestone. If that milestone's `**Done when:**` is satisfied, set `**Status:** done` and ask one question whether the next planned milestone is still correct.
- `plane`: do not edit the file roadmap or mutate Plane. Prepare a curated roll-up containing accepted scope, issue refs, verification, and the eventual completion result.
- `none`: skip roadmap mutation.

Any file-roadmap edit lands in `@`; Step 3 describes it. A later confirmed discard abandons it with the rest of the stack.

## Step 3: Show the Stack

Resolve the trunk first — jj's built-in `trunk()` only sees remote bookmarks and falls back to `root()` in a local-only repo:

```bash
read -r TRUNK TRUNK_BOOKMARK < <(<starting-a-change skill dir>/scripts/trunk-rev)
```

It prints e.g. `main@origin main`, `trunk() main`, or `main main` (local-only repo). If it fails, stop and have the user run `jj bookmark create main -r <base>`, then start Step 3 over. Use `$TRUNK` wherever this skill writes `trunk()`.

```bash
jj log -r "$TRUNK..@"
jj log -r "$TRUNK..@ & conflicts()"
```

The conflicts command must print nothing. If it doesn't, stop and resolve.

If `@` is non-empty and undescribed, `jj describe -m "<message>"` before proceeding — never land undescribed work.

**Trunk bookmark** = `$TRUNK_BOOKMARK`.

## Step 4: Shape the Stack

Ask **one** question: keep the granular changes, squash to one change per plan task, or squash the stack into one change total?

Execute with `jj squash --from <rev> --into <rev>` or `jj squash -r <rev>` (into parent). Never squash without asking. Squashing rewrites or abandons revisions, so nothing captured before this step identifies the stack any more.

**Derive now, after shaping — never earlier:**

- **Head** = `@-` if `@` is empty, else `@`.
- **Stack-root** = `roots($TRUNK..@)`.

Re-run `jj log -r "$TRUNK..@ & conflicts()"` once more; squashing can surface a conflict.

## Step 5: Present Options

Present exactly these 3 options, then wait:

```
Implementation complete. What would you like to do?

1. Land on trunk locally
2. Push and open a Pull Request
3. Keep the stack as-is (I'll handle it later)

Which option?
```

Discard is not on the menu. It happens only when the user types `discard` (see below).

### Option 1: Land on trunk locally

If the stack is not already based on current `$TRUNK`, rebase it. First list what else hangs off the stack — side changes such as the loose WIP `starting-a-change` stepped beside, or other workspaces: `jj log -r "(roots($TRUNK..@):: ~ ($TRUNK..@)) ~ (empty() & description(exact:\"\"))"`. If that prints nothing, `jj rebase -d "$TRUNK" -s <stack-root>`. If it prints something, ask one question: carry it along (`-s <stack-root>` moves it too; it stays attached to the same stack change with its own diff) or stop so the user can relocate it first. There is no "leave it behind" option — `jj rebase -r` would re-parent that work onto the old trunk and strip the stack content from its tree. Then re-run the Step 3 conflict check and the test suite — a green run only proves the tree it ran on. If either fails, stop and investigate; nothing has landed, and `jj undo` reverts the rebase.

Then `jj bookmark set <trunk-bookmark> -r <head>`. No push.

### Option 2: Push and open a PR

```bash
jj bookmark create <name> -r <head>
jj git push -b <name>
gh pr create --head <name> --base <trunk-bookmark>
```

Pass `--head` explicitly: in a colocated repo Git's HEAD is usually detached, so `gh` cannot infer the bookmark you just pushed. Or open the URL the push prints. Do not push trunk.

### Option 3: Keep as-is

Report the stack's change IDs. Leave bookmarks and workspaces untouched.

### If the user asks to discard the work

Confirm first:

```
This will permanently abandon:

- Changes: <change-id list from $TRUNK..@>

Type 'discard' to confirm.
```

Wait for that exact word. Then: `jj abandon "$TRUNK..@"`.

## Step 6: Finalize Provider State

For `session` and `none`, continue to cleanup.

For Kata, branch on the completed action:

- **Local land + `completion=landed`:** after the bookmark moves successfully, derive each shaped final commit ID. Close each child sequentially with an issue-specific message, `--commit <commit-id>`, and `--test <exact-command>`. Then verify every child is closed and the `sjujperpowers-plan` parent has no open blocking predecessors before closing it with reviewed plan/spec paths and the aggregate verification command.
- **PR created + `completion=pull_request`:** only after `gh pr create` returns a URL, close each child with `--pr <url>` and its verification evidence. Close the `sjujperpowers-plan` parent only after all child blockers are closed and local acceptance criteria pass.
- **PR created + `completion=landed`:** comment with the PR URL and leave every issue open.
- **Keep as-is:** comment with current change IDs and leave every issue open.
- **Confirmed discard or failed land/publication:** comment with the result and leave every issue open.

Use the exact Kata close contract:

```bash
kata --project <project> --json close <ref> \
  --reason done \
  --message "<issue-specific completed scope and Jujutsu change ID>" \
  --commit <final-commit-id> \
  --test "<verification command>"
```

For pull-request completion, replace `--commit` with `--pr <url>` when a stable final commit is not available. Never close or claim the `sjujperpowers-plan` parent while a child blocker or local acceptance criterion remains open.
For Plane, render one curated roll-up after the action and Kata finalization. Do not apply it or close the external outcome automatically.

## Step 7: Workspace Cleanup

For a `.workspaces/<name>/` directory created by starting-a-change, cleanup runs only after local land or confirmed discard. Anything else belongs to the host. Pull-request and keep-as-is outcomes retain the workspace.

If cwd is that workspace, return to the default workspace first. Then `jj workspace forget <name>` and remove the directory.

If subagent-driven development supplied a per-plan recovery workspace, remove only that exact directory after successful local land or confirmed discard. Retain it for pull-request and keep-as-is outcomes so the stack remains resumable.

## Quick Reference

| Option | Rebase/bookmark | Push | Keep workspace |
|--------|-----------------|------|----------------|
| 1. Land locally | yes, no push | - | - |
| 2. Open PR | bookmark on head | `jj git push -b` | yes |
| 3. Keep as-is | - | - | yes |
| Discard (`discard` only) | `jj abandon "$TRUNK..@"` | - | - |

## Common Rationalizations

| Excuse | Reality |
|--------|---------|
| "Tests passed earlier this session" | Run the suite on the tree you are about to land. |
| "They obviously want it landed" | Present the menu and wait. |
| "I'll offer to discard — they seem done" | Discard is not on the menu. Only when they ask. |
| "'Yeah, get rid of it' counts" | Only the typed word `discard` authorizes `jj abandon`. |
| "The push was rejected — force-push will fix it" | Stop. Investigate. Never force-push unless they ask. |
| "Trunk is obviously `main`" | Use `trunk-rev`'s answer and its bookmark. Wrong trunk is expensive to undo. |
| "Undescribed change is fine" | Describe non-empty `@` before landing. |
| "I'll squash, they won't mind" | Ask first. Never squash without asking. |
