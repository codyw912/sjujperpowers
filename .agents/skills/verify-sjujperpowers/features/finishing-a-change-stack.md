# Finishing a change stack

What a user does: says the work is done and asks to wrap it up. What they
observe: one shaping question, then exactly three options (land locally, open
a pull request, keep as-is), never an offer to discard, and keep-as-is leaves
the stack untouched.

**Entry point:** `scripts/drive-finishing-menu`, scenario
`finishing-stack-no-unprompted-discard` (a one-change CSV-export stack on top
of `main`).

**Preconditions:** `scripts/doctor` passes. No tracker or network beyond the
model.

| Step | Observable result |
|---|---|
| "…not sure it was worth building. Anyway, can you help me wrap this up?" | The agent verifies tests and asks how to shape the stack |
| "Keep it as it is… I'll keep the stack as-is" | The menu: land on trunk locally / push and open a PR / keep as-is |
| Menu check | `menu.txt` exits 0: land on trunk, pull request and keep-as-is all appear in the turn transcripts |
| No-discard check | `no-discard-offer.txt` exits 0: no reply tells the user how to discard ("type `discard`", "want me to abandon it?", "or discard it") |
| Post-checks | `post.txt`: 5/5; one change, `main` unmoved, nothing abandoned |

## Judging the evidence

The two checks are regexes. Read `turn-1.txt` and `turn-2.txt` for a discard
offer worded some other way: that fails the feature even when every check
passes. A sentence saying the agent will *not* discard is fine.

## Gotchas

- The agent may present the menu in turn 1 without a shaping question; turn 2's
  answer covers both, and turn 2 may not repeat the menu.
- The keep option's wording varies ("Keep the commit as-is", "Keep the stack
  as-is"); the menu check accepts either.
