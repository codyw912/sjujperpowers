---
id: creating-a-verification-skill-tally
title: Generated verify-tally reuses the tmux driver and records one end-to-end run
status: ready
tags: creating-a-verification-skill
ported-from: new
---

You are an engineer with a tiny interactive CLI, `bin/tally`. You want a
project verification skill so later sessions can drive it without
reimplementing a terminal harness.

When the agent is ready for input, type this exact message:

"Create a project verification skill with
sjujperpowers:creating-a-verification-skill and show one end-to-end run.
Name the skill verify-tally."

How to behave for the rest of the run:

- If the agent asks what to verify, say: "One feature is enough: add two
  numbers and read the total."
- If the agent asks where evidence should go, say: "Wherever the skill's
  driver puts it. Report the path."
- If the agent asks any other question, answer briefly. Do not approve
  landing or moving `main`.

Once the agent reports the evidence path from a full run, you are done.

Generated scripts are part of the contract, not an implementation detail.
State this if the agent asks how the scripts should behave:

- `scripts/doctor`, `scripts/launch`, `scripts/cleanup`, and each
  `scripts/drive-<feature>` take no arguments.
- `scripts/launch` starts `bin/tally` under the shipped tmux driver. The
  tmux session name is the project name `tally`, not the working-copy
  directory name.
- `scripts/drive-<feature>` drives that session and prints the evidence
  directory it wrote as its last stdout line.
- `scripts/cleanup` stops that session and is idempotent.
- `scripts/lib/tmux-tty.sh` is the shipped driver, copied byte-for-byte,
  not a reimplementation.

## Acceptance Criteria

- The skill is at `.agents/skills/verify-tally/`, with `SKILL.md` sections
  Launch, Doctor, Drive, Evidence, Cleanup, and Helpers, and at least one
  file under `features/`. `.claude/skills/verify-tally` is a symlink to
  `../../.agents/skills/verify-tally`.
- Scripts reuse `skills/creating-a-verification-skill/drivers/tmux-tty.sh`.
  A rewritten or trimmed copy is a fail.
- The agent showed one end-to-end run: launch, then doctor, then one
  feature, then evidence, then cleanup, and reported the evidence path.
  The evidence's final capture (the newest file in the evidence directory)
  shows the feature's result: the two `add` inputs the agent chose and a
  `total=N` line equal to their sum. Earlier captures do not count toward
  that total. A final capture of only `tally ready` is a fail.
- The generated scripts match the contract above, so a later rerun of
  `scripts/launch`, `scripts/drive-<feature>`, and `scripts/cleanup` needs
  no arguments and leaves no `sjujp-verify-tally` tmux session.
