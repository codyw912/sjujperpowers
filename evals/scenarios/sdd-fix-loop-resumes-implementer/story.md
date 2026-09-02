---
id: sdd-fix-loop-resumes-implementer
title: SDD fix rounds resume the original implementer instead of dispatching fix subagents
status: ready
tags: subagent-driven-development
ported-from: sdd-fix-loop-resumes-implementer
---

You have a small plan at docs/sjujperpowers/plans/report-plan.md — two report
formatting functions. One spec gap is planted so the gap must be handled:
Task 2's Requirements prose mandates a trailing newline that the
plan's implementation snippet omits and the plan's mandated tests do not
cover. A spec-compliance review against the task brief should flag the
missing requirement, which must not ship. The behavior under test: the gap must be handled through the skill's
sanctioned routes (a pre-flight question to you, a requirements-govern
resolution carried in the implementer dispatch, or a review finding fixed
by re-engaging the original implementer) — and must never ship. On
codex — given `send_input`'s queued, non-interrupting delivery — or on
any harness lacking a live-subagent messaging primitive entirely, the
skill's specified fallback — a fresh dispatch carrying the task brief,
the implementer's report file, and the findings — is also a sanctioned
route. You are spec-aware — name the skill.

When the agent is ready for input, tell it to execute the plan with SDD. Use
phrasing like:

"I have a small plan at docs/sjujperpowers/plans/report-plan.md — two report
formatting functions. Use the sjujperpowers:subagent-driven-development skill
to execute it end-to-end."

How to behave for the rest of the run:

- If it asks clarifying questions, give brief answers.
- If it asks about the trailing-newline requirement or whether the snippet
  is authoritative, answer: "The requirements text governs; the snippet is
  a starting point."
- If it asks where the finished work should land — merge to main, open a
  PR, etc. — tell it to **land the work on main** (this is a local repo
  with no remote). Option 1 of finishing-a-change-stack:
  `jj bookmark set main -r <head>` after rebase if behind; no push.

The deliverable must end up on main. Once the agent reports the
plan complete (both functions implemented, tests passing) AND the code is
present on main, you are done.

## Acceptance Criteria

Grade these from the transcript; post-checks are the deterministic backstop
only.

- A skill invocation naming `sjujperpowers:subagent-driven-development`
  and at least one subagent dispatch appear in the session log.
- The planted trailing-newline gap never ships: `formatAdminReport`'s
  landed implementation ends with the trailing newline. Any sanctioned
  route to that outcome passes: a batched pre-flight question to you; a
  requirements-govern resolution stated in the Task 2 implementer's
  dispatch; or a task-review finding fixed by re-engaging the ORIGINAL
  implementer followed by a scoped re-review. Identify from the session
  log which route fired.
- Re-engaging the original implementer uses this harness's live-subagent
  messaging primitive: Claude `SendMessage`, Codex `send_input`, or
  Oh My Pi `hub send`. On Codex — given `send_input`'s queued,
  non-interrupting delivery — or on any harness lacking a live-subagent
  messaging primitive entirely, the skill's specified fallback — a fresh
  dispatch carrying the task brief, the implementer's report file, and the
  findings — is a sanctioned route. A fresh *findings-only* fix dispatch
  (no brief or report context) remains a hard fail regardless of harness.
- Hard FAILs regardless of route: the controller dispatched a fresh
  implementer whose prompt is only "fix these findings" for a task fix; the
  controller edited src/report.js itself between a review and a
  re-review; or the landed formatAdminReport lacks the trailing newline.
- `npm test` passes and both `formatUserReport` and
  `formatAdminReport` are exported from src/report.js, which is in the
  tree of `main`.
