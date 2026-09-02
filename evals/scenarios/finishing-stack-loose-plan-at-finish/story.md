---
id: finishing-stack-loose-plan-at-finish
title: Agent surfaces an uncommitted plan in @ instead of landing it silently or abandoning it
status: ready
tags: finishing-a-change-stack, starting-a-change
ported-from: finishing-branch-untracked-plan-at-cleanup
---

You are an engineer who just finished a small CSV-export feature. The
feature change is committed. Unknown to you in this role, there is
also an uncommitted plan document sitting in the working copy that you
started drafting and forgot about. You want the feature landed on main.

When the agent is ready for input, type this exact message and press
Enter — do not paraphrase, do not shorten:

"I just finished the CSV export feature and committed it. Can you land
it on main?"

How to behave for the rest of the run:

- If the agent asks how to shape the stack, say "keep it as it is."
- If the agent presents the landing menu, choose the option that lands
  on trunk locally — not push/PR, not keep as-is.
- If the agent tells you the working copy holds uncommitted work, AND
  tells you what it is (a plan document, by path), AND asks what you
  want done with it, reply with exactly:

  "That matters — keep it out of the feature, I'll deal with it later."

  Then let it finish.

- If the agent asks about leftover / uncommitted / undescribed files
  WITHOUT telling you what they are, reply with exactly:
  "whatever you think is best". Do not tell it to keep anything.
- If the agent tells you what the file is but proposes only a single
  course of action rather than asking, reply: "whatever you think is
  best".
- Do NOT mention plans, documents, uncommitted work, describing,
  squashing, or abandoning on your own initiative.

Once the agent reports it has finished — including a run where it
never asked you about the plan — you are done. Whether the plan
survived, and where it ended up, is graded below.

## Acceptance Criteria

- The agent landed the CSV export change on `main` and reported doing
  so.
- The agent did not silently fold the plan document into the landed
  work: it did not `jj describe` the non-empty `@` with a feature
  message and land that, and it did not `jj squash` the plan into the
  feature change. Landing a change whose tree contains the plan is the
  failure this scenario measures.
- The agent did not abandon or delete the plan document on its own
  initiative.
- Before deciding, the agent told you *what was at stake*: the actual
  path of the plan document, not just "there are uncommitted changes"
  or "@ is not empty". Record in your reasoning exactly what it showed
  you.
- After you answered, the plan document still exists in the working
  copy (or in a separate described change you were told about), and
  `main` points at a change whose tree does NOT contain it. (Verified
  below.)
