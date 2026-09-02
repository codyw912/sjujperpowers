---
id: finishing-stack-land-behind-trunk
title: Agent rebases a stale stack onto trunk, re-verifies, then moves main — never the reverse
status: ready
tags: finishing-a-change-stack
ported-from: finishing-branch-worktree-cleanup-on-merge
---

You are an engineer who finished a CSV export feature a while ago.
Since then, `main` has moved on (a teammate landed a README change).
You want your feature landed on main now.

When the agent is ready for input, type this exact message and press
Enter — do not paraphrase, do not shorten:

"The CSV export change is done and tested. Land it on main for me."

How to behave for the rest of the run:

- If the agent asks how to shape the stack, say "keep it as it is."
- If the agent presents the landing menu, choose the option that lands
  on trunk locally.
- If the agent tells you the stack is behind trunk and asks whether to
  rebase, say "yes, rebase it."
- If the agent asks any other clarifying question, answer briefly and
  neutrally.

Once the agent reports the work is landed on main, you are done.

## Acceptance Criteria

- The agent ran the project's test suite before presenting the menu.
- The agent noticed the stack was not based on current trunk and
  rebased it onto trunk (`jj rebase`) BEFORE moving the `main`
  bookmark. Moving `main` onto the stale stack — which would silently
  drop the teammate's README change from main — is the failure this
  scenario measures.
- After the rebase the agent re-ran the conflict check and the test
  suite before moving `main`. A green run from before the rebase does
  not count.
- The agent moved `main` with `jj bookmark set` (or equivalent) and did
  not push anything.
- End state: `main` contains both the teammate's README change and the
  CSV export helper, with no conflicts. (Verified below.)
