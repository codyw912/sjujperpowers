# Tracker outcomes (Linear roadmap provider)

What a user does: works in a repository whose `.sjujperpowers/config.json` sets
`roadmap.provider` to `linear`, and asks for a design. What they observe: the
agent either uses the outcome they authorize, or asks for one; it never makes
one up and never creates one on the strength of the provider setting alone.

**Entry point:** an agent session started in the fixture with this checkout's
`skills/` (the drive scripts run `omp -p` with `.omp/config.yml`
`skills.customDirectories` pointing here).

**Preconditions:** `scripts/doctor` passes, including the `linear` MCP server
in `~/.omp/agent/mcp.json`. Fixtures come from `evals/scenarios/` via
`evals/run setup`.

## Case 1: no reference, no authorization (`scripts/drive-outcome-ask`)

Scenario `tracking-providers-linear-no-outcome`.

| Step | Observable result |
|---|---|
| Ask for a health-report design with no outcome | The reply asks for a `linear:CEW-<n>` reference (or which issue to use) and stops |
| Post-checks | `post.txt`: 3/3, no spec, no roadmap file |
| Provenance | `skills-loaded.txt` lists skills under this checkout's `skills/` |

## Case 2: a direct request creates the outcome (`scripts/drive-outcome-create`)

Scenario `tracking-providers-linear-create-outcome`. Writes one real
`[eval scratch] verify-sjujperpowers outcome` issue in Linear team CEW.

| Step | Observable result |
|---|---|
| Ask to create the issue and use it as the outcome | `mcp__linear_save_issue` appears in the agent's own session; no `omp -p` subprocess |
| (If the agent asks a design question) answer once | The spec is written and committed |
| Created check | `created.txt` shows the spec's `**Outcome:** linear:CEW-<n>` line |
| Post-checks | `post.txt`: 6/6 |

## Gotchas

- An agent may do one read-only Linear search before asking in case 1. The
  scenario allows it; a write fails the case.
- Case 2 sometimes stops at a design question after creating the issue; the
  drive answers once. If it still has no spec after turn 2, the post-checks fail.
- Archive the scratch issues periodically; nothing else reads them.
