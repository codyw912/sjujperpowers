---
name: tracking-providers
description: Resolves optional roadmap and execution providers for Sjujperpowers workflows and enforces their authority boundaries. Use before roadmapping, brainstorming, writing plans, starting changes, executing plans, or finishing a change stack when a repository may configure .sjujperpowers/config.json.
---

# Tracking Providers

## Overview

Repositories may independently choose where roadmap outcomes and durable execution state live. Specs and plans remain versioned in the repository under every provider combination.

| State | Authority |
| --- | --- |
| Portfolio priority and outcome acceptance | Roadmap provider |
| Approved behavior and architecture | Versioned spec |
| Work decomposition and instructions | Versioned plan |
| Cross-session claims, dependencies, blockers, completion | Execution provider |
| Immediate session progress | Harness-native todos |
| SDD review rounds, rulings, briefs, reports, recovery | Per-plan SDD workspace |
| Implementation and landing history | Jujutsu |

Roadmap and execution providers are independent. `file + kata` is as valid as `plane + kata`; Kata never requires Plane.

## Configuration

A repository may commit `.sjujperpowers/config.json`:

```json
{
  "version": 1,
  "roadmap": {
    "provider": "plane",
    "project": "Example Product"
  },
  "execution": {
    "provider": "kata",
    "project": "example-product",
    "completion": "landed"
  }
}
```

Credentials, service URLs, daemon addresses, and machine-specific paths belong in environment variables or ignored local configuration, never this file.

No file means:

```json
{
  "version": 1,
  "roadmap": { "provider": "file" },
  "execution": { "provider": "session", "completion": "landed" }
}
```

Supported roadmap providers:

- `file` — `docs/sjujperpowers/roadmap.md` owns outcomes.
- `plane` — an existing `plane:<identifier>` owns the outcome; integration is reference-only.
- `none` — no persistent roadmap authority.

`linear` is reserved but unsupported. Do not accept it as configuration until a real provider exists.

Supported execution providers:

- `session` — harness-native todos only.
- `kata` — Kata owns durable cross-session issue state.
- `none` — no persistent execution state beyond the plan and current conversation.

`completion` is `landed` by default and may be `pull_request`.

## Resolve before mutation

Every lifecycle skill resolves configuration before changing versioned artifacts or issue state:

```bash
node <tracking-providers skill dir>/scripts/resolve-config.mjs \
  --root "$(jj root)"
```

The command prints one normalized JSON object. Skills branch on that output; they never parse the committed JSON independently.

When execution is `kata`, checked resolution verifies, in order:

1. the `kata` executable exists;
2. `kata health --json` reaches the daemon;
3. `kata projects show <project> --json` resolves the configured project.

Failure stops before creating or editing a spec, plan, issue, or Jujutsu change. `--no-runtime-check` is only for offline inspection and deterministic tests. Lifecycle skills MUST NOT use it.

## Source references

Specs use the roadmap provider's native header:

- Plane: `**Outcome:** plane:PROJ-12`
- File roadmap: `**Milestone:** M1 — Outcome title`
- Bootstrap/no roadmap: `**Outcome:** none (bootstrap)`

Plans carry one provider-neutral header copied exactly from the spec:

- `**Source:** plane:PROJ-12`
- `**Source:** file:M1 — Outcome title`
- `**Source:** none (bootstrap)`

The source is opaque to the execution provider. Kata stores it as metadata but does not interpret or synchronize it.

Kata issue references use Kata's qualified form, such as `example-product#abc4`. Carry the exact reference into the Jujutsu description and completion evidence.

## Kata plan activation

After a Kata-backed plan is committed, materialize it:

```bash
node <tracking-providers skill dir>/scripts/materialize-plan.mjs \
  --root "$(jj root)" \
  --plan docs/sjujperpowers/plans/YYYY-MM-DD-feature.md
```

The command repeats checked provider resolution before mutation, creates one containment parent plus one child per numbered plan task, and prints normalized refs. The parent is labeled `sjujperpowers-plan`; children are labeled `sjujperpowers-task`. Every child also blocks the parent, so the parent cannot become ready before all children close. Automatic selection MUST use `kata next --label sjujperpowers-task --json` and can never claim a plan root.

Stable idempotency keys derive from the Kata project and repository-relative plan path, so retry the same command after a partial failure; do not create replacement issues manually. The parent and children record `sjujperpowers.plan`, `sjujperpowers.spec`, and `sjujperpowers.source` metadata. Children additionally record `sjujperpowers.task`. The source is provider-neutral, so `file + kata`, `plane + kata`, and bootstrap sources materialize identically.

Recover a named plan's mapping in a fresh session with:

```bash
kata --project <project> --json list \
  --status open \
  --label sjujperpowers-task \
  --meta "sjujperpowers.plan=<repository-relative-plan-path>"
```

Sort the returned issues numerically by `metadata["sjujperpowers.task"]`. Reconcile that list with the execution or SDD recovery ledger and supply the lowest-numbered child not marked complete to starting-a-change. Open completed children intentionally remain open until the configured landing or publication milestone, so open-state alone cannot identify the next task. Project-wide `kata next` is only for work without a named plan.

## Plane edition compatibility

Plane support is reference-based: do not claim to create, update, or close remote work automatically. A human or a separately authorized integration applies curated roll-ups.

Use modules to group focused initiatives on Plane editions without Initiatives. Coordinate cross-project efforts with linked work items in each participating project rather than assuming a paid or unavailable Initiative feature.

## Completion boundary

Verification records evidence but does not close Kata work. Close only after the configured completion event succeeds:

- `landed` — the local landing completed and the final commit ID is known.
- `pull_request` — publication succeeded and the PR URL is known.

`keep-as-is`, failed landing, failed publication, and discarded work leave the issue open with a substantive comment describing the state.
