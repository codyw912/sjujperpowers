---
name: roadmapping
description: Use when starting a new project, when a brainstorm reveals work too large for one spec, or when your human partner asks where the project is or what comes next - keeps a living milestone roadmap that specs and plans hang off
---

# Roadmapping

## Overview

Roadmapping orients work to the configured outcome authority. The default `file` provider uses `docs/project/roadmap.md`; `plane` carries an existing external outcome reference without editing a local roadmap; `none` intentionally skips persistent roadmap state. Milestones and external outcomes are results, not tickets. Hierarchy: roadmap source → spec → plan → task.

**Announce at start:** "I'm using the roadmapping skill to [create | revise | orient] the project roadmap."

**REQUIRED SUB-SKILL:** Use sjujperpowers:tracking-providers before the first question or versioned edit.

Template: [roadmap-template.md](roadmap-template.md)

If `jj root` fails, stop: "This isn't a jj repo. Run `jj git init --colocate` and re-run, or tell me to continue without VCS steps."

Run the checked provider resolver from the tracking-providers skill. A Kata-backed repository must pass executable, daemon, and project preflight before this skill creates or edits a versioned artifact.

Use `docsRoot` from the normalized configuration for every roadmap path below. `docs/project` is only the default.

## Provider paths

### File

Classify and say which mode:

| Mode | When | Do |
|------|------|----|
| **Create** | New project, or no `docs/project/roadmap.md` | Interview → propose → approve → write → commit → hand off |
| **Revise** | Brainstorming or finishing flagged drift, or the user changed direction | Show affected milestones → propose minimal edit → approve → Decisions line → commit |
| **Orient** | "Where are we / what's next" | Read the file, report, offer the next spec |

#### Create

Interview one question at a time: vision, non-goals, what must be true at the end, natural milestone boundaries, order and why, done-when for each.

Propose the milestone list with your recommendation. Get approval. Write the file from the template. Then:

```bash
jj commit docs/project/roadmap.md -m "Add project roadmap"
```

Hand off to `sjujperpowers:brainstorming` for M1's first spec.

#### Revise

Show the affected milestones. Propose the minimal edit. Get approval. Record a `## Decisions` line (`- YYYY-MM-DD — <decision> — <why>`). Commit:

```bash
jj commit docs/project/roadmap.md -m "Update project roadmap"
```

#### Orient

Read the file. Report in ≤10 lines: the active milestone, its done-when, open questions, and the next planned milestone. Offer to start brainstorming on the next spec.

### Plane

Require an existing provider-qualified outcome such as `plane:PROJ-12`. Plane support is reference-based: never claim to create, edit, or close the work item. Do not create or update `docs/project/roadmap.md`.

Orient by reporting the supplied outcome reference, the configured Plane project, known acceptance context, and the next spec. If the request needs a new or revised outcome, explain that it must be changed in Plane and stop until an existing reference is available.

On Plane editions without Initiatives, use modules for focused initiatives and linked work items for cross-project efforts. Never assume the Initiatives feature exists.

### None

Report that persistent roadmap state is intentionally disabled. Do not create a roadmap or manufacture a milestone. Hand off to brainstorming with `none (bootstrap)` or another explicit no-roadmap source.

## Rules

- Roadmap sources describe outcomes, not task lists.
- File roadmaps should contain 3-7 milestones. More means the vision is really several projects.
- A milestone's done-when must be checkable without opinion.
- Never add dates, estimates, or owners to file-roadmap milestones.
- File-roadmap decisions are append-only.

<HARD-GATE>
Never write or edit the file roadmap without the user approving the milestone list or edit in chat.
</HARD-GATE>

## Common Rationalizations

| Excuse | Reality |
|--------|---------|
| "I'll jot milestones in the spec" | Specs die with the feature. Persist the decomposition here. |
| "Dates will keep us honest" | Dates rot. Done-when does not. |
| "Too small for a roadmap" | If it needed decomposing, persist that decomposition. |
| "I'll edit first, they can revert" | The gate is approval of the list, not of the file after the fact. |
| "More milestones = more clarity" | More than 7 means this is several projects. Split the vision. |
