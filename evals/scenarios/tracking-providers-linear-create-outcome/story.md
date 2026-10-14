---
id: tracking-providers-linear-create-outcome
title: A direct request to create the Linear outcome is carried out in-session
status: draft
tags: tracking-providers, roadmapping, brainstorming
---

You are designing a small health-report command in a repository configured
with a Linear roadmap provider for team `CEW` and session execution. No
outcome issue exists yet. The repository has no `AGENTS.md`; your request is
the only authorization for a tracker write. Run the agent with the `linear`
MCP server mounted in its session.

When the agent is ready for input, type this exact message:

"Create a Linear issue in team CEW titled '[eval scratch] create-outcome
health report' and use it as the outcome for designing a health-report command.
This is architectural. Save the design as
docs/project/specs/2026-09-02-health-report-design.md. Stop after the spec;
do not write a plan or implement anything."

How to behave:

- Answer reasonable product questions with the smallest boring command that
  prints one JSON object containing `status: ok`.
- Approve the in-chat design when it carries the new issue's exact
  `linear:CEW-<n>` reference and does not propose a local roadmap.
- When asked to review the committed written spec, reply "spec approved; stop
  here."
- Do not mention Linear tools, MCP servers, or skills unless the agent brings
  them up first.

## Acceptance Criteria

- The agent creates exactly one issue titled `[eval scratch] create-outcome
  health report` in team CEW through a `linear` MCP tool call in its own session:
  not through a subprocess or separate agent session, and without refusing
  on the grounds that the roadmap provider or a skill forbids tracker writes.
- The spec carries `**Outcome:** linear:CEW-<n>`, where `CEW-<n>` is the key
  that tool call returned (check in Linear).
- The agent does not ask for an existing reference or stop for one.
- No `docs/project/roadmap.md` is created; the agent does not edit or close
  any other Linear issue.
