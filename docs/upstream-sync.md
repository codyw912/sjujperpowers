# Syncing with upstream

sjujperpowers is a short stack of changes rebased onto [obra/superpowers](https://github.com/obra/superpowers). Two bookmarks define it:

- `fork-base` — the upstream commit the stack currently sits on. Local only; moved by the sync procedure and nothing else.
- `main` — the fork's head. Pushed to `origin` (this fork). It does **not** track `main@upstream`.

The stack is exactly `fork-base..main`. Its first change is mechanical (prune harness plumbing and the official-listing pipeline, global rename via `scripts/fork-rename.mjs`, simplified Claude hook); the rest are semantic (jj port, roadmap layer, docs). `jj log -r 'fork-base..main'` lists them.

Remotes: `upstream` = obra/superpowers, `origin` = codyw912/sjujperpowers. Do not rely on jj's built-in `trunk()` here: it is `latest(main@origin | main@upstream | …)` by committer timestamp, so it flips to `main@upstream` whenever upstream is newer. The fork's own skills resolve the trunk with `skills/starting-a-change/scripts/trunk-rev`, which prefers `main@origin`. If other tooling needs `trunk()` to be stable, pin it in this repo's config: `revset-aliases."trunk()" = "main@origin"`.

## Procedure

```bash
jj git fetch --remote upstream
jj log -r 'fork-base..main@upstream'                          # what's new upstream
jj log -r '(roots(fork-base..main):: ~ (fork-base..main)) ~ (empty() & description(exact:""))'   # preflight: every non-empty or described descendant -s will carry along
OLD_BASE=$(jj log -r fork-base --no-graph -T 'commit_id')     # kept for the audit below
jj rebase -s 'roots(fork-base..main)' -d main@upstream        # moves the stack and every descendant of its root
jj bookmark set fork-base -r main@upstream
jj log -r 'fork-base..main & conflicts()'                     # changes needing resolution
```

`-s` moves every descendant of the stack root — not just what sits on `main`, but also side branches or workspaces forked from any change in the stack. That is usually what you want: such work stays attached to the same stack change, with its own diff intact (it shows as conflicted only until the stack's conflicts are resolved). The preflight uses the same descendant set as `-s`, minus empty undescribed changes (your `@`), so it lists everything meaningful that will move; if it names something you do not want moved, `jj rebase` it elsewhere first. Do not use `-r` for this: it leaves descendants behind on the old base.

jj records conflicts inside commits, so the rebase always succeeds. Resolve each conflicted change oldest first (`jj new <change>`, fix, `jj squash`), then audit the tree from a fresh change on `main` — these are the things a clean 3-way merge cannot know about:

```bash
jj new main
node scripts/fork-rename.mjs                                  # new upstream files still carry the old name
rg -n '\bgit (add|checkout|branch|worktree|merge|rebase|stash|commit|push|pull|status|diff|log|rev-parse)\b' skills
jj diff --from "$OLD_BASE" --to fork-base --summary | rg '^A '   # new upstream files: prune or keep?
ls skills                                                     # new upstream skills: keep, port, or drop?
```

Squash each fix into the change it belongs to (`jj squash --into <change>`), run the suites in `docs/testing.md`, then `jj bookmark set main -r @-` if anything remains on top and `jj git push --remote origin -b main`.

## What to expect

A trial of this procedure against an upstream feature branch (the session-diagnosis skill) (24 files changed vs v6.3.0, 18 of them under `skills/`, one new skill) produced conflicts in `CODE_OF_CONDUCT.md` (upstream edited, fork deleted — keep the deletion), `README.md`, and `docs/testing.md`; 20 files needing `fork-rename.mjs` (including the new skill directory, whose name carried the upstream name); three git-command lines that had crept back into skills; and 21 new upstream files to triage (a new skill, its test, and two upstream dogfood docs under its `docs/<upstream-name>/` tree, which the fork prunes). Expect real reconciliation wherever the port rewrote paragraphs upstream also changed: `subagent-driven-development`, `brainstorming`, `writing-plans`, `executing-plans`, `starting-a-change`, `finishing-a-change-stack`, plus `README.md`/`docs/testing.md` almost every time.

Files the fork deleted that upstream later edits surface as modify/delete conflicts; keep the deletion unless the prune decision changed.
