---
name: creating-a-verification-skill
description: Use when a project has no verify-<project> skill and verifying-by-risk needs behavior evidence, or when asked to create a project verification skill, feature map, or rerunnable verify recipes
---

# Creating a Verification Skill

Generate a project-owned skill that launches the project, drives its user-facing features, and leaves evidence, so verification runs the same way every time instead of being improvised.

**Announce at start:** "I'm using the creating-a-verification-skill skill to build verify-<project>."

**Core principle:** Scripts over prose. Every recipe a later agent needs is a script it can rerun. The skill is not done until one full run has worked end to end and its evidence path is reported.

## Generated layout

```
.agents/skills/verify-<project>/
  SKILL.md                # Launch, Doctor, Drive, Evidence, Cleanup, Helpers
  features/<feature>.md   # one per user-facing feature
  scripts/
    doctor                # preflight: tools, build, config; exit non-zero with the fix
    launch                # start the app under the driver
    drive-<feature>       # one per feature; prints its evidence dir as the last line
    cleanup               # stop everything; safe to run twice
    lib/tmux-tty.sh       # copied unchanged from this skill's drivers/
.claude/skills/verify-<project> -> ../../.agents/skills/verify-<project>
```

- `<project>` is the repository's short name, lowercase with hyphens. It is also the driver session name.
- Scripts take no arguments, start with `#!/usr/bin/env bash` and `set -euo pipefail`, are executable, and resolve paths from their own location. They do not depend on the caller's working directory.
- Create the Claude Code symlink with `ln -s ../../.agents/skills/verify-<project> .claude/skills/verify-<project>`. OMP dedupes by name and realpath, so it does not load the skill twice.
- `SKILL.md`, `features/**`, and `scripts/**` under `verify-*`, and the `.claude/skills/verify-*` link, are protected paths for verifying-by-risk. Changing a recipe or retargeting the link later needs operator approval.

## Process

1. **Map features.** Read the README, CLI help, entry points, and existing tests. List the user-facing features: what a user does and what they observe. Pick the few that matter most; this is not a coverage exercise.
2. **Write `features/<feature>.md`** for each one:
   - **Entry point:** the command, screen, or endpoint.
   - **Preconditions:** state, config, or data the feature needs.
   - **Steps:** each step paired with the observable result that proves it worked.
   - **Gotchas:** timing, flaky output, environment quirks found while driving it.
3. **Write `scripts/doctor`.** It checks every tool and build product `launch` needs and exits non-zero with the exact fix when one is missing. Run it.
4. **Write `scripts/launch` and `scripts/cleanup`.** For CLI and TUI projects, copy [drivers/tmux-tty.sh](drivers/tmux-tty.sh) to `scripts/lib/tmux-tty.sh` byte for byte, and call it rather than reimplementing tmux handling:

   ```bash
   #!/usr/bin/env bash
   set -euo pipefail
   here=$(cd "$(dirname "$0")" && pwd)
   root=$(cd "$here/../../../.." && pwd)
   "$here/lib/tmux-tty.sh" start <project> "$root" <command...>
   "$here/lib/tmux-tty.sh" wait <project> '<ready pattern>' 30
   ```

   `cleanup` is `"$here/lib/tmux-tty.sh" stop <project>`, plus removing any temporary state that `launch` created.
5. **Write one `scripts/drive-<feature>` per feature.** It follows the feature file's steps with `send`/`keys`/`wait`, captures the screen after each observable result into the directory printed by `tmux-tty.sh evidence-dir <project>`, and prints that directory as its last line of output. A step whose result never appears fails the script.
6. **Write `SKILL.md`** for the project with these sections, in this order:
   - `## Launch`, `## Doctor`, `## Drive`, `## Evidence`, `## Cleanup`, `## Helpers`.
   - Each section names the script and when to run it. Drive lists the features with links to their files. Evidence says where evidence lands (`$XDG_STATE_HOME/sjujperpowers/evidence/<project>/`, outside the repository). Helpers documents the driver commands.
   - Frontmatter: `name: verify-<project>` and a "Use when verifying <project> behavior…" description.
7. **Run it end to end** for at least one feature, with cleanup running whether or not the earlier scripts pass (a failed run otherwise leaves the tmux server behind to block the retry) and the first failure's exit status kept:

   ```bash
   scripts/doctor && scripts/launch && scripts/drive-<feature>; rc=$?
   scripts/cleanup; crc=$?; [ "$rc" -ne 0 ] || rc=$crc
   echo "exit status: $rc"; [ "$rc" -eq 0 ]
   ```

   Fix whatever breaks and run again. Report the commands, their exit statuses, and the evidence path.
8. **List what the recipes read.** Name every file `scripts/doctor`, `launch`, and the drive scripts depend on beyond the project's source: `justfile` recipes they call, toolchain and build config. Tell the operator to add them to `.sjujperpowers/risk.toml`'s `protected` list (see verifying-by-risk's hk-conventions.md: protect whatever the declared checks read). Do not edit `risk.toml` yourself; it is protected.

## Driver commands

| Command | Does |
|---|---|
| `start <name> <dir> <cmd...>` | start `cmd` in a detached 200x50 pane on a private tmux server |
| `send <name> <text>` | type text literally, then Enter |
| `keys <name> <key>...` | send raw tmux keys (`C-c`, `Up`, `Escape`) |
| `wait <name> <ERE> [s]` | wait for the screen to match (default 10 s); on timeout, print the screen and exit 1 |
| `capture <name> <file>` | write the visible screen |
| `stop <name>` | kill the private server; idempotent |
| `evidence-dir <project>` | create and print a fresh evidence directory |

Each name gets its own tmux socket, so a run never touches the operator's sessions. A browser driver does not exist yet. For web projects, stop and tell the operator.

## Red Flags

| Thought | Reality |
|---|---|
| "I'll describe the steps in SKILL.md; scripts are overkill." | Prose drifts and gets improvised. Scripts rerun. |
| "The tmux driver needs one tweak for this app." | Keep the copy unchanged. Put app quirks in the project's scripts. |
| "Doctor passed, so the skill works." | Not done until launch → drive → evidence → cleanup has run. |
| "Evidence can go in the repo for convenience." | Jujutsu snapshots it into the change. Keep it under the state dir. |
| "This feature is flaky, so skip the wait and sleep." | `wait` on the observable result; record the gotcha in the feature file. |

Maintenance mode (updating an existing verify skill after features change) is not covered yet.
