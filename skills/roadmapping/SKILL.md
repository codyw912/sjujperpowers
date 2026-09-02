---
name: roadmapping
description: Use when starting a new project, when a brainstorm reveals work too large for one spec, or when your human partner asks where the project is or what comes next - keeps a living milestone roadmap that specs and plans hang off
---

# Roadmapping

## Overview

The roadmap is the persisted form of the decomposition brainstorming does in chat. One file: `docs/sjujperpowers/roadmap.md`. Milestones are outcomes, not tickets. Hierarchy: roadmap milestone → spec → plan → task. Each layer names the one above.

**Announce at start:** "I'm using the roadmapping skill to [create | revise | orient] the project roadmap."

Template: [roadmap-template.md](roadmap-template.md)

If `jj root` fails, stop: "This isn't a jj repo. Run `jj git init --colocate` and re-run, or tell me to continue without VCS steps."

## Three Modes

Before your first question, classify and say which:

| Mode | When | Do |
|------|------|----|
| **Create** | New project, or no `docs/sjujperpowers/roadmap.md` | Interview → propose → approve → write → commit → hand off |
| **Revise** | Brainstorming or finishing flagged drift, or the user changed direction | Show affected milestones → propose minimal edit → approve → Decisions line → commit |
| **Orient** | "Where are we / what's next" | Read the file, report, offer the next spec |

### Create

Interview one question at a time: vision, non-goals, what must be true at the end, natural milestone boundaries, order and why, done-when for each.

Propose the milestone list with your recommendation. Get approval. Write the file from the template. Then:

```bash
jj commit docs/sjujperpowers/roadmap.md -m "Add project roadmap"
```

Hand off to `sjujperpowers:brainstorming` for M1's first spec.

### Revise

Show the affected milestones. Propose the minimal edit. Get approval. Record a `## Decisions` line (`- YYYY-MM-DD — <decision> — <why>`). Commit:

```bash
jj commit docs/sjujperpowers/roadmap.md -m "Update project roadmap"
```

### Orient

Read the file. Report in ≤10 lines: the active milestone, its done-when, open questions, and the next planned milestone. Offer to start brainstorming on the next spec.

## Rules

- Milestones are outcomes, not task lists.
- 3-7 milestones is the sweet spot. More means the vision is really several projects.
- A milestone's done-when must be checkable without opinion.
- Never add dates, estimates, or owners.
- Decisions log is append-only.

<HARD-GATE>
Never write or edit the roadmap without the user approving the milestone list or edit in chat.
</HARD-GATE>

## Common Rationalizations

| Excuse | Reality |
|--------|---------|
| "I'll jot milestones in the spec" | Specs die with the feature. Persist the decomposition here. |
| "Dates will keep us honest" | Dates rot. Done-when does not. |
| "Too small for a roadmap" | If it needed decomposing, persist that decomposition. |
| "I'll edit first, they can revert" | The gate is approval of the list, not of the file after the fact. |
| "More milestones = more clarity" | More than 7 means this is several projects. Split the vision. |
