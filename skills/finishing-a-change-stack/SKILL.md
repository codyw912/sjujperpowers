---
name: finishing-a-change-stack
description: Use when implementation is complete, all tests pass, and you need to decide how to land a jj change stack
---

# Finishing a Change Stack

## Overview

**Core principle:** Verify tests → Update the roadmap → Show the stack → Shape it → Present options → Execute choice → Clean up.

**Announce at start:** "I'm using the finishing-a-change-stack skill to complete this work."

If `jj root` fails, stop: "This isn't a jj repo. Run `jj git init --colocate` and re-run, or tell me to continue without VCS steps."

## Step 1: Verify Tests

Run the project's full test suite (`npm test` / `cargo test` / `pytest` / `go test ./...`).

**If tests fail**, report the failures and stop — the menu comes after a green suite:

```
Tests failing (<N> failures). Must fix before completing:

[Show failures]
```

**If tests pass:** continue to Step 2.

## Step 2: Update the Roadmap

Runs before the stack is inspected so the edit is part of what lands. If `docs/sjujperpowers/roadmap.md` is missing, skip silently.

If the plan names a milestone: make sure this plan's path is listed under that milestone's `**Plans:**` — writing-plans normally added it already; add it only if missing. If the milestone's `**Done when:**` is now satisfied, set `**Status:** done` and ask (one question) whether the next planned milestone is still the right next step.

The edit lands in `@`; Step 3 describes it. A later discard abandons it with the rest of the stack.

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

## Step 6: Workspace Cleanup

Only if this work ran in a `.workspaces/<name>/` directory created by starting-a-change. Anything else belongs to the host — leave it.

Runs for option 1 and confirmed discards. Options 2 and 3 keep the workspace.

If cwd is that workspace, return to the default workspace first. Then `jj workspace forget <name>` and remove the directory.

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
