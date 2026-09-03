# Pi and Oh My Pi Tool Mapping

Skills speak in actions ("dispatch a subagent", "create a todo", "read a file"). On Pi and Oh My Pi these resolve to the tools below.

## Oh My Pi

Skill instructions use Claude-style identifiers such as
`sjujperpowers:tracking-providers`. In OMP, translate every
`sjujperpowers:<name>` reference to `skill://<name>`. Do not include the
`sjujperpowers:` namespace in an OMP skill URI.

Oh My Pi ships the tools Pi core leaves optional, so skills map directly:

| Action skills request | Oh My Pi equivalent |
| --- | --- |
| Read a skill | `read skill://<name>` — the harness already requires this before acting; the bootstrap extension is redundant there and harmless |
| Dispatch a subagent (`Subagent (general-purpose):` template) | `task` with `tasks[]`; pick `agent` by role (`scout` for read-only research, `reviewer` for reviews, omit for implementers) |
| Resume a live subagent (SDD fix rounds 1-3) | `hub` `send` to the agent id from the dispatch result |
| Wait on dispatched subagents | `hub` `wait` — bounded, never a polling loop |
| Task tracking ("create a todo", "mark complete") | `todo` |
| Ask the user a structured question | `ask` |

## Pi

| Action skills request | Pi equivalent |
| --- | --- |
| Dispatch a subagent (`Subagent (general-purpose):` template) | Use an installed subagent tool such as `subagent` from `pi-subagents` if available |
| Task tracking ("create a todo", "mark complete") | Use an installed todo/task tool if available, otherwise track tasks in the plan or `TODO.md` |

## Subagents

Pi core does not ship a standard subagent tool. The `pi-subagents` package is a strong optional companion and provides a `subagent` tool with single-agent, chain, parallel, async, forked-context, and resume/status workflows. If no subagent tool is available, do not fabricate `Task` calls; execute sequentially in the current session or explain that the optional subagent capability is not installed.

## Task lists

Pi core does not ship a standard task-list tool. If a todo/task extension is installed, use its documented tool. Otherwise use Sjujperpowers plan files, checklists in Markdown, or a repo-local `TODO.md` for task tracking. Older Sjujperpowers docs may refer to `TodoWrite`; treat that as the task-tracking action above.
