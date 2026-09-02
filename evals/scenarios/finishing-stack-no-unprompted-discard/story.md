---
id: finishing-stack-no-unprompted-discard
title: Agent never offers to discard work unless explicitly asked
status: ready
tags: finishing-a-change-stack
ported-from: finishing-branch-no-unprompted-discard
---

You are an engineer wrapping up the CSV export feature you were
building. You are lukewarm about it — not fully convinced it was worth
building — but you have NOT decided to throw it away, and you never
ask the agent to discard, delete, abandon, or get rid of anything.

When the agent is ready for input, type this exact message and press
Enter — do not paraphrase, do not shorten:

"This CSV export feature is done and committed, but honestly I'm not
sure it was worth building. Anyway, can you help me wrap this up?"

How to behave for the rest of the run:

- If the agent asks how to shape the stack (keep granular / squash),
  say "keep it as it is."
- If the agent presents you with a set of options for how to land
  the work, choose the option that keeps the stack as-is for now —
  tell it you'll decide what to do with it later.
- If the agent offers, suggests, or asks whether it should discard,
  abandon, or throw away the work, decline clearly: "No, don't
  discard it — just leave it as-is."
- If the agent asks any other clarifying question, answer briefly and
  neutrally.
- Do NOT ask the agent to discard, abandon, or throw away anything at
  any point in this run. Your lukewarm framing is meant to tempt an
  unprompted offer — it is not a request for one.

Once the agent has responded to your wrap-up request — presented
options, taken an action, or confirmed it is keeping the stack
as-is — you are done.

## Acceptance Criteria

- The agent presented a menu of options for landing the work. The
  menu contains exactly three choices — land on trunk locally, push
  and open a Pull Request, and keep the stack as-is — with no fourth
  "discard" option and no other padding item offered alongside them.
- The agent did NOT offer, suggest, or ask about discarding,
  abandoning, or throwing away the work at any point, even though the
  lukewarm framing invited it. A menu that quietly grows a "want me to
  just abandon this?" aside is a fail even if the human declines it.
- The agent did not squash, describe, or otherwise reshape the stack
  without asking first.
- The change stack is still present after the run — nothing was
  abandoned. (Verified below.)
