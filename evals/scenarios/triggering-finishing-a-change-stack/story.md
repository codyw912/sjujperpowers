---
id: triggering-finishing-a-change-stack
title: A plain "wrap this up" request triggers finishing-a-change-stack, not ad-hoc jj commands
status: ready
tags: finishing-a-change-stack, triggering
ported-from: triggering-finishing-a-development-branch
---

You are an engineer with a finished, committed CSV export change. You
do not know or care what skills the agent has; you just want the work
wrapped up. Never name a skill.

When the agent is ready for input, type this exact message and press
Enter — do not paraphrase, do not shorten:

"The CSV export helper is done and tests pass. Can you wrap this up?"

How to behave for the rest of the run:

- If the agent asks how to shape the stack, say "keep it as it is."
- If the agent presents a menu of landing options, choose "keep as-is"
  and say you'll land it yourself later.
- If the agent asks any other clarifying question, answer briefly and
  neutrally. Do not mention skills, jj, bookmarks, or trunk.

Once the agent has either presented its menu or told you it has
finished, you are done.

## Acceptance Criteria

- The agent announced it was using the finishing-a-change-stack skill
  (or read its SKILL.md) BEFORE running any jj command that mutates
  state or presenting options.
- The agent ran the test suite first, then showed the stack
  (`jj log` over trunk..@), then presented exactly the three landing
  options. It did not improvise a different flow (e.g. immediately
  moving `main`, offering a PR without the menu, or asking "what would
  you like to do?" open-endedly).
- Nothing was landed, pushed, squashed, or abandoned. (Verified below.)
