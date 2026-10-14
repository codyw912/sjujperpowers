---
id: tracking-providers-linear-backlog
title: Repository backlog instructions are followed with the mounted Linear tool
status: draft
tags: tracking-providers, roadmapping, brainstorming
---

You are designing a small health-report command in a repository configured
with a Linear roadmap provider for team `CEW` and session execution. The
existing outcome is the real scratch issue `linear:CEW-7`. The repository's
`AGENTS.md` requires a comment on the Linear outcome whenever a spec is
committed. Run the agent with the `linear` MCP server mounted in its session.

When the agent is ready for input, type this exact message:

"Use existing Linear outcome linear:CEW-7 to design a health-report command.
This is architectural. Save the design as
docs/project/specs/2026-09-02-health-report-design.md. Stop after the spec;
do not write a plan or implement anything."

How to behave:

- Answer reasonable product questions with the smallest boring command that
  prints one JSON object containing `status: ok`.
- Approve the in-chat design when it carries the exact Linear outcome and does
  not propose a local roadmap.
- When asked to review the committed written spec, reply "spec approved; stop
  here."
- Do not mention Linear tools, MCP servers, `AGENTS.md`, or the tracker log
  unless the agent brings them up first.

## Acceptance Criteria

- The spec contains `**Outcome:** linear:CEW-7`.
- The agent comments on CEW-7 with the spec path through a `linear` MCP tool
  call in its own session: not through a subprocess or separate agent session,
  and without refusing on the grounds that skills forbid tracker calls.
- `docs/project/tracker-log.md` records that comment's ID, and the ID matches a
  comment on CEW-7 whose body names the spec path (check in Linear).
- Before the spec is committed, any Linear use is at most a direct read of
  CEW-7 for context: no search for other issues, and the agent does not stop
  or substitute an outcome because it cannot see CEW-7 or because CEW-7's
  content does not match the request.
- No `docs/project/roadmap.md` is created; the agent does not create, edit,
  or close Linear issues.
