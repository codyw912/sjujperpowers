# Linear Roadmap Provider Design

**Outcome:** plane:SJUP-3

## Summary

Add `linear` as a roadmap provider next to `plane`. Plane keeps working unchanged, Kata stays the execution provider, and Linear support is reference-only, as Plane's is: no skill creates, edits, synchronizes, or closes Linear issues.

The roadmap providers move into a small registry. The resolver dispatches to it, and one contract test holds every external provider to the same checks.

## Decisions

- **D1: Registry, not another branch.** Roadmap providers live in `skills/tracking-providers/scripts/roadmap-providers.mjs`, one entry per provider in the order `file`, `plane`, `linear`, `none`. The resolver keeps the shared roadmap checks and calls the entry's `normalize`. The operator chose this over a single extra branch in `normalizeRoadmap`.
- **D2: Linear configuration.** `{"provider": "linear", "team": "CEW", "project": "Optional Project"}`. `team` is required. After trimming it must match `^[A-Z][A-Z0-9]*$`; lowercase is rejected, not uppercased. The rule is this design's choice, not a documented Linear limit, and may be loosened later. `project` is optional, a non-empty string checked like Plane's `project`, and appears in the resolved output only when set. Resolved field order is `provider`, `team`, `project`.
- **D3: References are team keys.** Linear issue keys belong to the team, not the project: an issue in any project of team `CEW` is `CEW-<n>`, and moving it between projects keeps the key. References are therefore `linear:<TEAM>-<n>`, such as `linear:CEW-123`, and carry no project. The configured `project` records which Linear project a repository's outcomes belong to; Linear itself shows each issue's project. A repository that wants keys naming the project uses its own Linear team; this needs no code change.
- **D4: Same reference flow as Plane.** Specs carry `**Outcome:** linear:CEW-123` immediately under the title, and plans copy it unchanged as `**Source:** linear:CEW-123`. `materialize-plan.mjs` already treats the source as an opaque string, so it does not change.
- **D5: No source validation at runtime.** Nothing checks that a plan's `Source` matches the configured provider. Reference patterns in the registry are the provider contract that the tests check and the docs cite. The operator chose this over refusing mismatched sources when a plan is materialized.
- **D6: The default does not change.** Without a config file the roadmap provider is still `file`. Each repository chooses its provider in its own configuration; the skills and docs do not record which repositories use which provider.

## Registry

Every entry has `name` and `normalize(raw, invalid)`. `normalize` receives the roadmap object after the shared checks, and `invalid(field, message)` is the resolver's error builder bound to the config path. It returns the resolved roadmap object or throws the error `invalid` builds. Entries for external providers (`plane`, `linear`) also have:

- `fields`: the required and optional configuration keys;
- `referencePattern`: a regular expression for the provider's references, anchored at both ends. Plane: `^plane:[A-Z0-9]+-[1-9][0-9]*$`. Linear: `^linear:[A-Z][A-Z0-9]*-[1-9][0-9]*$`;
- `exampleReference`: one valid reference (`plane:SJUP-12`, `linear:CEW-123`).

`file` and `none` take no keys beyond `provider`. Their behavior is unchanged.

## Resolution and errors

`normalizeRoadmap` keeps its order: absent means `file`; a non-object fails on `roadmap`; any key that no provider defines fails as `roadmap.<key> is not supported`; a provider name not in the registry fails as `roadmap.provider must be one of: file, plane, linear, none`. The entry then validates its own fields:

| Input | Error field | Message |
| --- | --- | --- |
| `linear` without `team` | `roadmap.team` | must be a non-empty string |
| `team` not a string, or blank | `roadmap.team` | must be a non-empty string |
| `team` such as `cew`, `9AB`, `C-W` | `roadmap.team` | must be an uppercase Linear team key such as CEW |
| `project` on `linear` not a non-empty string | `roadmap.project` | must be a non-empty string |
| `team` on `plane`, `file`, or `none` | `roadmap.team` | is not valid for provider <name> (the wording the resolver already uses for `project` on `file`) |
| `roadmap.workspace` on any provider | `roadmap.workspace` | is not supported |

Plane's resolved output and its field errors stay exactly as today. The only user-visible change outside Linear is the provider list in the `roadmap.provider` error.

## Tests

`tests/tracking-providers/test-resolve-config.mjs`:

- remove the case that rejects `linear` as reserved;
- add normalization of `linear` with and without `project`, including trimming;
- add rejection cases from the table above;
- keep every Plane, `none`, file-default, and Kata separation case unchanged.

New `tests/tracking-providers/test-roadmap-providers.mjs` runs the same checks over each external registry entry:

- its minimal configuration resolves through `normalizeConfig`, and normalizing the result's roadmap again gives the same object;
- removing each required field fails and names that field;
- its `exampleReference` matches its own `referencePattern` and no other provider's;
- a plan whose header is `**Source:** <exampleReference>` passes through `parsePlan` and `materializePlan` with a recording fake Kata, and the parent and every child record exactly that `sjujperpowers.source`.

The full `tests/tracking-providers/*.mjs` suite runs file by file.

## Documentation

- `skills/tracking-providers/SKILL.md`: list `linear` with its config, remove the "reserved but unsupported" line, add Linear to Source references, and state that Linear support is reference-only.
- `skills/roadmapping/SKILL.md`: a Linear section matching the Plane one, including that keys are team keys.
- `skills/brainstorming/SKILL.md`: the classification step and the spec-header rule name `linear:<identifier>` next to `plane:<identifier>`.
- `skills/writing-plans/SKILL.md`: the Source rule copies Linear outcomes unchanged, like Plane.
- `skills/finishing-a-change-stack/SKILL.md`: the curated, unapplied roll-up applies to Linear as to Plane.
- `skills/using-sjujperpowers/SKILL.md`: the tracking routing line names Linear.
- `README.md`: list `linear`, and state that Linear support is reference-only.

The September tracking-provider spec and plan stay as written; they record the earlier decision.

## Behavioral eval

New scenario `evals/scenarios/tracking-providers-linear`, mirroring `tracking-providers-plane`: a repository configured with `{"provider": "linear", "team": "DEMO"}` and session execution, the outcome `linear:DEMO-12`, and checks that the spec carries `**Outcome:** linear:DEMO-12`, the plan carries `**Source:** linear:DEMO-12`, no roadmap file appears, and the agent claims no Linear writes.

## Live acceptance

Through the `linear` MCP server, create one scratch issue in team `CEW` whose description links SJUP-3. In a temporary jj repository configured for `linear` + `kata`, run the checked resolver (with Kata preflight), confirm the scratch issue exists through the MCP server, then parse and materialize a plan whose source is that issue's reference, using the recording fake Kata, so no real Kata issues are created. Record the issue key and the result on SJUP-3. The scratch issue stays in Linear. It is the only Linear write this work makes.

## Delivery

SJUP-3 asks for a pull request on `codyw912/sjujperpowers`; the operator merges. The publication plan reports `automatic` for this repository, so no grant is needed. The repository's Kata completion event stays `landed`, so finishing-a-change-stack's "PR created + `completion=landed`" rule applies: comment the PR URL on the Kata issues and leave them open until the merged change reaches local `main`.

## Non-goals

- Writing to Linear from any skill, or a Linear API client in skill scripts.
- Checking a plan's `Source` against the configured provider.
- Changing the no-config default or this repository's roadmap provider.
- Configurations spanning several Linear teams.
- Editing the September tracking-provider spec or plan.
