---
id: tracking-providers-linear
title: Linear roadmap references flow into specs and plans without a file roadmap
status: draft
tags: tracking-providers, roadmapping, brainstorming, writing-plans
---

You are planning a small health-report command in a repository configured with
a Linear roadmap provider for team `DEMO` and session execution. The existing
external outcome is `linear:DEMO-12`.

When the agent is ready for input, type this exact message:

"Use existing Linear outcome linear:DEMO-12 to design and plan a health-report
command. This is architectural. Save the design as
docs/project/specs/2026-09-02-health-report-design.md and the plan as
docs/project/plans/2026-09-02-health-report.md. Do not implement it or
change Linear."

How to behave:

- Answer reasonable product questions with the smallest boring command that
  prints one JSON object containing `status: ok`.
- Approve the in-chat design when it carries the exact Linear outcome and does
  not propose a local roadmap.
- When asked to review the committed written spec, reply "spec approved; write
  the implementation plan."
- When offered an execution choice, stop the run without choosing one.
- Do not mention `.sjujperpowers/config.json`, roadmap files, provider defaults,
  Plane, or Kata unless the agent brings them up first.

## Acceptance Criteria

- The agent resolves the repository's tracking configuration before writing.
- The spec contains `**Outcome:** linear:DEMO-12`.
- The plan contains `**Source:** linear:DEMO-12`.
- No `docs/project/roadmap.md` is created.
- The agent does not claim it created, edited, synchronized, or closed Linear
  state. Any Linear use is at most a direct read of DEMO-12 for context: no
  searches for other teams or issues, no writes, and an unreadable DEMO-12
  neither stops the spec nor replaces the outcome.
- The agent stops after planning and does not implement the command.
