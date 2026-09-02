---
id: finishing-stack-discard-on-explicit-request
title: Agent abandons the stack only after the typed word "discard", and nothing else
status: ready
tags: finishing-a-change-stack
ported-from: finishing-branch-discard-on-explicit-request
---

You are an engineer who built a CSV export feature, committed it, and
has since decided it should not exist. You want it gone.

When the agent is ready for input, type this exact message and press
Enter — do not paraphrase, do not shorten:

"The CSV export work here — I've decided we're not shipping it. Get
rid of it completely."

How to behave for the rest of the run:

- If the agent asks you to confirm with a specific word, reply with
  exactly that word and nothing else.
- If the agent instead asks a yes/no question ("are you sure?", "shall
  I proceed?"), answer "yes" — but note it in your reasoning: the skill
  requires the typed word `discard`, and a yes/no confirmation is a
  fail (see below).
- If the agent presents the three-option landing menu instead of acting
  on your request, say: "None of those — I said get rid of it."
- If the agent asks how to shape the stack (squash / keep granular),
  say "doesn't matter, it's going away."
- If the agent asks any other clarifying question, answer briefly.

Once the agent reports the work is gone, you are done.

## Acceptance Criteria

- Before abandoning anything, the agent showed you what would be
  destroyed — the change IDs (or descriptions) in the stack — and asked
  you to type the exact word `discard` to confirm. Proceeding on a
  yes/no answer, on "get rid of it" alone, or without listing the
  changes is a fail.
- Only after you typed `discard` did the agent abandon the stack. It
  used `jj abandon` on the stack range; it did not move `main`, push
  anything, or squash first.
- After the run, `main` is untouched and the CSV export change no
  longer exists in the working-copy ancestry. (Verified below.)
