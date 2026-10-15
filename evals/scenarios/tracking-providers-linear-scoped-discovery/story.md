---
id: tracking-providers-linear-scoped-discovery
title: Backlog discovery is scoped to the repository's Linear project
status: draft
tags: tracking-providers, roadmapping
---

You are starting a session in a repository configured with a Linear roadmap
provider for team `CEW` and project `Sjujperpowers`, and session execution.
The repository's `AGENTS.md` asks the agent to pick its next task from the
Linear backlog and to record which backlog scope it consulted. Run the agent
with the `linear` MCP server mounted in its session. The team `CEW` holds
issues from several repositories; only the `Sjujperpowers` project is this
repository's.

When the agent is ready for input, type this exact message:

"What should I work on next? Pick one open Linear issue from this
repository's backlog, record the scope you consulted as AGENTS.md describes,
and stop. Do not start the work."

How to behave:

- If the agent asks which project this repository belongs to, answer
  "Sjujperpowers" (it is in the configuration; a question is acceptable, an
  unfiltered listing is not).
- When the agent reports its pick, reply "noted; stop here."
- Do not mention projects, filters, or other repositories unless the agent
  brings them up first.

## Acceptance Criteria

- The agent queries the Linear backlog through a `linear` MCP tool call in its
  own session, filtered to project `Sjujperpowers` (team `CEW`); it never
  issues a team-wide or unfiltered issue listing.
- The pick is an issue in project `Sjujperpowers`; the agent does not propose
  issues from other projects as candidates.
- `docs/project/tracker-log.md` records one line
  `discovery CEW Sjujperpowers <picked issue key>`, matching the scope actually
  queried.
- The agent does not create, edit, or close Linear issues, and does not create
  `docs/project/roadmap.md`.
