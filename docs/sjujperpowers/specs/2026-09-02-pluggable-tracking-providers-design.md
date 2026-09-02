# Pluggable Tracking Providers Design

**Milestone:** none (unplanned)

**Outcome:** none (bootstrap)

## Context

Sjujperpowers currently owns versioned roadmap, specification, and implementation-plan artifacts while its execution skills use harness-native todos and, for subagent-driven development, an ignored per-plan recovery workspace. That workspace contains `progress.md`, task briefs, reports, and review packages so a controller can resume safely after compaction.

Those mechanisms are effective inside one execution run but do not provide a project-visible ledger that humans and agents can query across sessions. Hosted trackers such as Plane or Linear solve a different problem: portfolio direction, prioritization, and cross-project coordination. Kata provides a local-first execution ledger with agent claims, dependencies, lifecycle state, and evidence-based closes.

The integration must preserve one authority for each kind of state. It must not turn Sjujperpowers into a synchronization engine or make an external service mandatory.

This bootstrap change has no external outcome because it establishes the mechanism through which later work can reference one.

## Goals

1. Let each repository independently select optional roadmap and execution providers.
2. Preserve current Sjujperpowers behavior when no provider configuration exists.
3. Keep specs and plans versioned with the repository regardless of provider choice.
4. Use Plane primarily for human-visible outcomes and Kata for activated local execution work.
5. Keep harness todos and SDD recovery artifacts even when Kata is enabled.
6. Make provider references traceable through specs, plans, Kata issues, and Jujutsu changes.
7. Close execution records only after the configured landing or publication milestone succeeds.
8. Support local and remote development without hard-coding a machine topology into the provider framework.

## Non-goals

- Implementing a Linear provider in the first rollout.
- Bidirectional synchronization between Plane and Kata.
- Automatically creating or mutating Plane work items in the first rollout.
- Replacing harness-native todos, SDD task briefs, reports, review packages, or recovery data.
- Migrating or federating existing Kata databases.
- Provisioning or exposing Kata infrastructure; runtime deployment belongs to each adopter's environment.
- Adding PostgreSQL, federation, or a shared multi-user Kata deployment before SQLite proves insufficient.
- Closing Plane outcomes automatically when one implementation issue closes.
- Requiring Plane features unavailable in an adopter's edition; use modules and linked work items when Initiatives are unavailable.

## Domain model

| Term | Definition |
| --- | --- |
| **Outcome** | A human-visible result whose direction, priority, and acceptance are owned by a roadmap provider. |
| **Spec** | The approved, versioned behavioral and design contract for an outcome. |
| **Plan task** | A stable, independently executable work package defined by a versioned implementation plan. |
| **Issue** | A mutable execution record owned by the execution provider. |
| **Controller todo** | Ephemeral session state used by the active harness to display immediate progress. |
| **Recovery workspace** | Ignored SDD artifacts that preserve task-local orchestration and review-loop position across compaction. |
| **Change** | The Jujutsu implementation identity associated with an issue. |
| **Activation** | The one-way process of turning an accepted outcome into repository artifacts and executable issues. |
| **Roll-up** | A curated summary published from completed local execution to the external outcome. |

A Plane workspace is an organizational boundary. A Plane project is a durable product or independently prioritized system. On Plane editions without Initiatives, modules group focused initiatives within a project and linked work items coordinate cross-project efforts. A Kata project is normally one repository's execution ledger. Multiple clones, worktrees, and Jujutsu workspaces for one repository bind to the same Kata project.

## Authority boundaries

| State | Authority |
| --- | --- |
| Portfolio priority, project placement, and outcome acceptance | Roadmap provider, primarily Plane |
| Approved behavior and architecture | Versioned spec |
| Work decomposition and implementation instructions | Versioned plan |
| Cross-session issue state, claims, dependencies, and blockers | Execution provider, primarily Kata |
| Immediate session progress | Harness-native todos |
| SDD rulings, review rounds, briefs, reports, and recovery | Ignored SDD recovery workspace |
| Implementation and landing history | Jujutsu |

Provider data flows through one-way activation:

```text
external outcome
  -> versioned spec
    -> versioned plan
      -> execution parent and child issues
        -> Jujutsu changes and verification evidence
          -> curated roll-up to the external outcome
```

The system does not continuously mirror all fields. It carries stable references between layers and publishes deliberate summaries at lifecycle boundaries.

## Project configuration

A repository may commit `.sjujperpowers/config.json`:

```json
{
  "version": 1,
  "roadmap": {
    "provider": "plane",
    "project": "Sjujperpowers"
  },
  "execution": {
    "provider": "kata",
    "project": "sjujperpowers",
    "completion": "landed"
  }
}
```

JSON is used because every supported harness can read it and provider scripts can validate it without adding a TOML parser. The committed file contains only non-secret project identity and policy.

Provider credentials, API endpoints, Kata daemon addresses, and machine-specific paths remain in environment variables or ignored local configuration.

When the file is absent, the normalized defaults are:

```json
{
  "version": 1,
  "roadmap": { "provider": "file" },
  "execution": { "provider": "session" }
}
```

Unknown versions, providers, fields with the wrong type, missing provider-specific required fields, or a failed selected-provider preflight produce an actionable error. They do not silently fall back to another authority.

## Provider contracts

Sjujperpowers exposes two semantic provider slots rather than one generic tracker interface. Roadmap and execution systems have different responsibilities and must not be treated as interchangeable implementations.

### Roadmap provider

Supported first-version values:

- `file`: current `docs/sjujperpowers/roadmap.md` behavior.
- `plane`: external Plane outcome references with manual creation and curated roll-up.
- `none`: no persistent roadmap requirement.

`linear` is reserved by the design but rejected until implemented.

The roadmap contract supports these workflow operations:

- orient to the active outcome;
- validate a provider-qualified outcome reference;
- carry the reference into specs and plans;
- render a curated completion summary;
- identify when human-level acceptance remains unresolved.

The first Plane implementation is reference-based. It accepts identifiers such as `plane:SJUP-12`; it does not claim to create, update, or synchronize the remote work item. Direct Plane API automation or a Kata connector is a later provider enhancement that must preserve this contract.

### Execution provider

Supported first-version values:

- `session`: current harness-native execution behavior.
- `kata`: Kata owns project-visible execution state.
- `none`: no persistent execution tracking beyond the versioned plan and current conversation.

The execution contract supports:

- materializing a plan into a parent and child issues;
- listing ready work;
- claiming one issue;
- recording a blocker;
- recording verification without closing;
- associating a Jujutsu change ID;
- completing an issue after the configured completion milestone.

The provider returns or records Kata's qualified references, such as `sjujperpowers#abc4`. Skills treat those references as opaque identities rather than parsing vendor database IDs.

### Kata preflight

Kata-backed workflows run one checked preflight before any spec, plan, issue, or Jujutsu mutation. It verifies the `kata` executable, daemon health, and the configured project with `kata health --json` and `kata projects show <project> --json`. A missing executable, unreachable daemon, or unknown/archived project stops the workflow without repository mutation. Offline inspection may bypass runtime checks explicitly, but lifecycle skills never use that bypass.

## Skill behavior

Roadmap and execution providers are resolved together at every workflow entry point. When execution is `kata`, roadmapping, brainstorming, and plan writing complete the checked Kata preflight before they create or edit versioned artifacts.

### Roadmapping

With `file`, preserve the existing create, revise, and orient modes.

With `plane`, orient and activation require a valid Plane outcome reference. The skill must not create or update `docs/sjujperpowers/roadmap.md`, because that would establish a second editable roadmap authority.

With `none`, roadmapping reports that the repository has intentionally disabled persistent roadmap state and hands off to brainstorming without manufacturing a milestone.

### Brainstorming

Architectural specs include an outcome header:

```markdown
**Outcome:** plane:SJUP-12
```

File-roadmap projects retain the existing milestone header. Plane projects use the provider-qualified outcome in place of a local milestone. Bootstrap work may use `none (bootstrap)` with an explicit explanation.

The spec remains authoritative for behavioral and architectural requirements. External outcome text supplies direction but does not replace the approved spec.

### Writing plans

Plans define one generic `**Source:**` value copied from the approved spec: a provider-qualified Plane outcome, a file-roadmap milestone, or `none (bootstrap)`. Roadmap and execution selection remain independent, so both Plane-backed and file-backed plans may materialize into Kata. Plans also define stable task numbers. When Kata is selected, plan completion materializes one `sjujperpowers-plan` parent for the activation and one `sjujperpowers-task` child per plan task. Every child has a containment parent link and blocks the parent, which keeps automatic task selection off the root and makes the root ready only after all children close. Each child records the plan path, source, and task heading as its requirements source.

The plan remains an immutable execution argument. Checkbox rendering may remain for readability, but checked state is not authoritative when Kata is configured.

### Starting a change

With Kata selected, the workflow:

1. resolves the configured Kata project;
2. for a named plan, recovers children by task label plus exact plan metadata, reconciles the recovery ledger, and validates the lowest-numbered incomplete child; only unnamed work uses `kata next --label sjujperpowers-task`, and neither path selects the plan root;
3. claims the issue;
4. performs the existing fresh-change isolation logic;
5. places the Kata reference in the Jujutsu description;
6. records the stable Jujutsu change ID on the issue.

Claim failure stops before repository mutation. If fresh-change creation fails after a claim, the workflow releases or documents the claim rather than leaving silent ownership behind.

Without Kata, existing loose-WIP protection and fresh-change behavior remain unchanged.

### Executing plans

Harness-native todos remain the current session's progress UI under every provider. With Kata selected, issue state is updated at the same task boundaries, but the skill does not add a second durable Markdown ledger.

### Subagent-driven development

The ignored per-plan workspace remains. Its responsibilities are task briefs, reports, review packages, rulings, fix-round position, and controller recovery after compaction.

Kata owns whether a plan task is unclaimed, active, blocked, or completed across sessions. `progress.md` owns only the controller's position inside an active task and its review loop. On resume, the controller reconciles both. A closed Kata issue paired with a mid-loop recovery record is an inconsistency, not permission to skip review.

### Finishing a change stack

The completion sequence is:

1. verify behavior and tests;
2. record verification evidence without closing the Kata issue;
3. shape the Jujutsu stack;
4. present the existing land, pull-request, or keep-as-is choice;
5. execute the chosen action;
6. close Kata implementation issues only after successful local landing, or after the explicitly configured pull-request milestone;
7. close the Kata parent only when all child blockers are closed and all local acceptance criteria are satisfied;
8. render one curated roadmap roll-up;
9. leave the external outcome open unless its human-level acceptance criteria are satisfied.

`completion` initially accepts `landed` or `pull_request`. The default is `landed`. `keep-as-is`, failed publication, and discarded work leave issues open.

Kata's typed commit evidence expects a commit SHA while Jujutsu change IDs are the stable working identity. The first implementation records verification with Kata's supported test/review evidence, includes the Jujutsu change ID in the message, and records a final commit ID only after stack shaping. A new Kata evidence type is not required for the pilot.

## Deployment boundary

The provider framework does not install or expose external services. Adopters provision Plane, Kata, credentials, daemon addresses, persistence, and backups in their own environment. Committed repository configuration contains only provider type, project identity, and completion policy. Machine-specific connection details remain in environment variables or ignored local configuration.

For Kata, a repository commits `.kata.toml` and every clone or Jujutsu workspace intended to share execution state resolves to the same project and daemon. Separate daemons remain separate authorities; this design does not federate or migrate them.

## Reference pilot

A reusable provider pilot:

1. selects Plane and Kata in a fixture or non-critical repository;
2. verifies the configured Kata daemon and project before versioned mutation;
3. references an existing Plane outcome in an approved spec;
4. copies the provider-neutral source into a versioned plan;
5. materializes one Kata parent and one child per plan task;
6. executes one child through claim, Jujutsu change, review, landing, and close;
7. inspects the same state through `kata tui`;
8. renders a curated completion summary without automatic remote mutation.

Success requires that the provider-free path still behaves exactly as before, `file + kata` and `plane + kata` both work, the Kata-enabled path leaves one authoritative durable issue state, a controller can resume from its SDD recovery artifacts, and no issue or external outcome closes before its configured completion boundary.

## Failure handling

- Missing project configuration uses documented defaults.
- Invalid explicit configuration fails closed with the exact invalid field.
- Selected Kata with no executable, an unreachable daemon, or an unavailable configured project stops before issue or repository mutation.
- Partial materialization reports created issue references and remains retry-safe; retries must not duplicate already materialized tasks.
- Claim conflicts identify the current owner and select no replacement implicitly.
- A repository mutation failure after claim records or releases the failed claim.
- A Plane reference that cannot be independently read remains an explicit unverified reference; the skill does not invent remote state.
- Provider and recovery-ledger disagreement is surfaced and reconciled before execution resumes.
- Landing or publication failure records the failure and leaves Kata issues open.

## Test strategy

Tests cover behavior rather than skill prose alone:

1. Configuration normalization with no file, every supported provider, malformed JSON, unknown versions, unknown providers, and missing required fields.
2. Existing file/session workflow fixtures remain unchanged when configuration is absent.
3. Plane mode requires and propagates an external outcome reference without writing a local roadmap.
4. Kata materialization is idempotent, maps one plan task to one child issue, and works with both Plane outcomes and file-roadmap milestones.
5. Child labels and child-to-parent blockers prevent automatic selection of the plan root and keep it unready until every child closes.
6. Kata preflight rejects a missing executable, unreachable daemon, and unknown project before versioned artifact mutation.
7. Claim happens before fresh-change mutation, and claim failure produces no Jujutsu change.
8. Harness todos and SDD artifact creation still occur with Kata enabled.
9. Resume reconciles Kata lifecycle with task-local recovery state.
10. Verification does not close an issue.
11. `keep-as-is`, failed land, and failed publication leave issues open.
12. Successful configured completion closes only the applicable local issues and renders, but does not automatically apply, the external roll-up.
13. An end-to-end reference pilot exercises project binding, preflight, task-only ready selection, claim, Jujutsu association, evidence, landing, root unblocking, close, and TUI visibility.

## Recorded decisions

- 2026-09-02 — Use separate roadmap and execution provider slots because portfolio and execution systems have different semantics.
- 2026-09-02 — Preserve current file/session behavior when project configuration is absent.
- 2026-09-02 — Ship Plane as the first reference-based external roadmap provider and Kata as the first durable execution provider.
- 2026-09-02 — Keep Plane reference-based initially; defer API mutation and connector synchronization until the workflow is familiar.
- 2026-09-02 — Keep deployment topology, persistence, credentials, and backup policy outside the public provider framework.
- 2026-09-02 — Use Plane modules for focused initiatives and linked project work items for cross-project efforts when Initiatives are unavailable.
- 2026-09-02 — Preserve harness todos and SDD recovery artifacts with Kata; Kata replaces only duplicated durable project-visible status.
- 2026-09-02 — Carry a provider-neutral plan source so `file + kata` remains valid and Kata does not depend on Plane.
- 2026-09-02 — Close Kata work only after successful landing or the explicitly configured pull-request milestone.
