---
id: sdd-re-review-scoped
title: SDD fix-loop round 2 re-review stays scoped to the two open findings
status: ready
tags: subagent-driven-development
ported-from: sdd-re-review-scoped
---

You are resuming an interrupted SDD session. The repo has a three-task plan
at docs/project/plans/metrics-plan.md, mid-execution: Task 1 is
complete, Task 2 ran one fix round that resolved one review finding and
left two Important findings open — unnamed magic numbers in formatDuration
(3600 and 60, with no named constants) and a formatting expression repeated
across its branches — and Task 3 is unstarted. The progress ledger at
.sjujperpowers/sdd/metrics-plan/progress.md records all of this, including
which model implemented Task 2 and has owned the fix loop so far:
`Task 2 implementer model: claude-haiku-4-5 (cheapest tier)`.

SKILL.md records BASE / FIX_BASE as commit IDs in the controller's notes
(the commit ID of `@-` with `@` empty, never a change ID) and does not
prescribe writing them to the ledger. This fixture still records
`Task 2: FIX_BASE <commit id>` on the ledger so a controller resuming
mid-loop can find the head the previous review saw.

You are spec-aware — name the skill.

Tell the agent:

"I had to restart our session. We were executing
docs/project/plans/metrics-plan.md with the
sjujperpowers:subagent-driven-development skill — the progress ledger is at
.sjujperpowers/sdd/metrics-plan/progress.md. Pick up where we left off and finish the
plan."

How to behave for the rest of the run:

- Let the agent proceed autonomously. The ledger's last Task 2 line is a
  fix round, not `complete`, so per its skill it must resume the loop at
  the next round — round 2, still inside the "resume the original
  implementer" range — rather than treating Task 2 as done or re-reviewing
  everything from scratch.
- If it asks you anything about how to run the fix loop (which
  implementer, whether to keep going), do NOT decide for it: answer "Your
  call — follow your skill."
- If it asks where the finished work should land, tell it to **land the
  work on main** (local repo, no remote): option 1 of
  finishing-a-change-stack, `jj bookmark set main -r <head>`, no push.

You are done when the agent reports the plan complete and Task 3's code is
present on main.

## Acceptance Criteria

Grade these from the transcript; post-checks are the deterministic backstop
only.

- A skill invocation naming `sjujperpowers:subagent-driven-development`
  appears in the session log.
- Round 2 dispatched a fix for the two open findings — a dispatch
  carrying both the magic-numbers finding and the repeated-expression
  finding, plus a pointer to the report file — on the same implementer
  that ran round 1 (rounds 1-3 stay on the original implementer per the
  skill). The round-1 implementer subagent is not live after this
  restart, so re-engaging it literally is impossible: use the harness
  messaging primitive if a live child exists (Claude `SendMessage`,
  Codex `send_input`, Oh My Pi `hub send`); otherwise the skill's
  specified fallback — a fresh dispatch carrying the task brief, the
  implementer's report file, and the findings — is a sanctioned
  realization of "the same implementer that ran round 1" here.
- After the fix, the agent dispatched a re-review SCOPED to exactly those
  two findings — a dispatch shaped like re-review-prompt.md's "Findings
  Under Verification" list, not a fresh task review. Identify from the
  session log which prompt fired: a dispatch that reviews Task 2's whole
  implementation from scratch, with no findings list at all, is a hard
  FAIL — SKILL.md is explicit that a re-review "is not a fresh review —
  the full review already happened." The re-review package must be built
  from FIX_BASE (the commit ID on the ledger) to `@`.
- Skipping the re-review outright (treating the fix as done without any
  re-review dispatch) is also a hard FAIL.
- A `Task 2: fix round 2/5 (<X> addressed, <Y> open — <one-liners>;
  changes <a>..<b>)` line was appended to the ledger in that exact
  format. A missing round-2 line, or one that drops the em dash or the
  change-ID range, is a hard FAIL.
- Task 3 was then implemented through the normal loop (implementer
  dispatch + task review) — not skipped and not folded into the Task 2
  fix.
- `npm test` passes, src/summary.js is present on main, and the two
  planted findings are actually fixed (named constants for 3600/60;
  padStart extracted so it is not triplicated).
