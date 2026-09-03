# Pluggable Tracking Providers Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use sjujperpowers:subagent-driven-development (recommended) or sjujperpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add optional roadmap and execution provider support while preserving Sjujperpowers' existing file-roadmap and session-todo behavior by default.

**Architecture:** A shared `tracking-providers` skill owns configuration normalization and Kata plan materialization. Existing lifecycle skills invoke that contract at their current decision boundaries; they retain harness todos and SDD recovery artifacts while delegating only durable cross-session issue state to Kata.

**Tech Stack:** Node.js ES modules and `node:test`, Markdown skills, Kata CLI v0.16.0, Jujutsu.

**Spec:** `docs/project/specs/2026-09-02-pluggable-tracking-providers-design.md`

**Milestone:** none (unplanned)

**Source:** none (bootstrap)

## Global Constraints

- Missing `.sjujperpowers/config.json` MUST normalize to roadmap provider `file` and execution provider `session`.
- Explicit invalid configuration MUST fail closed; it MUST NOT silently select another authority.
- Supported roadmap providers are `file`, `plane`, and `none`; `linear` remains rejected until implemented.
- Supported execution providers are `session`, `kata`, and `none`.
- Plane support is reference-based only; this plan MUST NOT create, mutate, or synchronize Plane work items.
- Plane Community Edition uses modules for focused initiatives and linked project work items for cross-project efforts; it MUST NOT depend on Plane Initiatives.
- Kata MUST own only durable cross-session issue state. Harness todos and SDD recovery artifacts remain active.
- Every Kata-backed workflow MUST verify the executable, daemon health, and configured project before creating or changing a spec, plan, issue, or Jujutsu change.
- Verification MUST NOT close Kata work. Closure happens only after successful `landed` completion or the configured `pull_request` milestone.
- Provider credentials, URLs, daemon addresses, and machine paths MUST NOT enter committed configuration.
- All CLI JSON output described below is a stable Sjujperpowers contract; raw Kata response shapes MUST be normalized before callers consume them.

---

### Task 1: Tracking configuration resolver

**Files:**
- Create: `skills/tracking-providers/SKILL.md`
- Create: `skills/tracking-providers/scripts/resolve-config.mjs`
- Create: `tests/tracking-providers/test-resolve-config.mjs`

**Interfaces:**
- Consumes: repository root path, optional `.sjujperpowers/config.json`, and injectable command probes for Kata.
- Produces: `resolveConfig(root, options) -> { version, configPath, roadmap, execution }`, `preflightKata(project, options)`, and a CLI that prints the normalized object only after required runtime checks succeed.
- Normalized roadmap shape: `{ provider: "file" | "plane" | "none", project?: string }`.
- Normalized execution shape: `{ provider: "session" | "kata" | "none", project?: string, completion: "landed" | "pull_request" }`.

- [ ] **Step 1: Write resolver contract tests**

Create `tests/tracking-providers/test-resolve-config.mjs` with temporary repositories and dependency injection for runtime checks:

```js
import assert from 'node:assert/strict';
import { mkdtemp, mkdir, writeFile } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import test from 'node:test';

import { normalizeConfig, resolveConfig } from '../../skills/tracking-providers/scripts/resolve-config.mjs';

async function fixture(config) {
  const root = await mkdtemp(join(tmpdir(), 'sjujperpowers-config-'));
  if (config !== undefined) {
    await mkdir(join(root, '.sjujperpowers'));
    await writeFile(join(root, '.sjujperpowers/config.json'), config);
  }
  return root;
}

test('missing config preserves file and session defaults', async () => {
  const root = await fixture();
  assert.deepEqual(await resolveConfig(root, { runtimeCheck: false }), {
    version: 1,
    configPath: null,
    roadmap: { provider: 'file' },
    execution: { provider: 'session', completion: 'landed' },
  });
});

test('plane and kata configuration is normalized', () => {
  assert.deepEqual(normalizeConfig({
    version: 1,
    roadmap: { provider: 'plane', project: 'Sjujperpowers' },
    execution: { provider: 'kata', project: 'sjujperpowers', completion: 'pull_request' },
  }, '/repo/.sjujperpowers/config.json'), {
    version: 1,
    configPath: '/repo/.sjujperpowers/config.json',
    roadmap: { provider: 'plane', project: 'Sjujperpowers' },
    execution: { provider: 'kata', project: 'sjujperpowers', completion: 'pull_request' },
  });
});
```

Add cases for malformed JSON, version other than `1`, `linear`, unknown provider names, wrong field types, missing Plane/Kata project names, invalid completion values, missing Kata executable, unreachable Kata daemon, and unknown Kata project. Use an injected `runCommand` to assert that a selected Kata provider calls `kata health --json` followed by `kata projects show <project> --json`, while every non-Kata configuration calls neither. Assert error messages name the exact file, failing preflight stage, and project where applicable.

- [ ] **Step 2: Run the resolver tests and verify RED**

Run:

```bash
node --test tests/tracking-providers/test-resolve-config.mjs
```

Expected: FAIL because `resolve-config.mjs` does not exist.

- [ ] **Step 3: Implement strict normalization and CLI output**

Create `skills/tracking-providers/scripts/resolve-config.mjs` using only Node built-ins. Export functions for tests and keep CLI handling below them:

```js
const DEFAULT_CONFIG = Object.freeze({
  version: 1,
  configPath: null,
  roadmap: Object.freeze({ provider: 'file' }),
  execution: Object.freeze({ provider: 'session', completion: 'landed' }),
});

export function normalizeConfig(raw, configPath) {
  if (!raw || raw.version !== 1) throw invalid(configPath, 'version', 'must equal 1');
  rejectUnknownKeys(raw, ['version', 'roadmap', 'execution'], configPath, 'root');

  const roadmap = normalizeRoadmap(raw.roadmap, configPath);
  const execution = normalizeExecution(raw.execution, configPath);
  return { version: 1, configPath, roadmap, execution };
}

export async function resolveConfig(root, options = {}) {
  const configPath = resolve(root, '.sjujperpowers/config.json');
  let text;
  try {
    text = await readFile(configPath, 'utf8');
  } catch (error) {
    if (error.code === 'ENOENT') return structuredClone(DEFAULT_CONFIG);
    throw error;
  }

  let raw;
  try {
    raw = JSON.parse(text);
  } catch (error) {
    throw new Error(`${configPath}: invalid JSON: ${error.message}`);
  }

  const config = normalizeConfig(raw, configPath);
  if (options.runtimeCheck !== false && config.execution.provider === 'kata') {
    await preflightKata(config.execution.project, {
      commandExists: options.commandExists ?? defaultCommandExists,
      runCommand: options.runCommand ?? defaultRunCommand,
      configPath,
    });
  }
  return config;
}

export async function preflightKata(project, { commandExists, runCommand, configPath }) {
  if (!commandExists('kata')) {
    throw invalid(configPath, 'execution.provider', 'selects kata but the kata executable is unavailable');
  }
  try {
    await runCommand('kata', ['health', '--json']);
  } catch (error) {
    throw invalid(configPath, 'execution.provider', `cannot reach the kata daemon: ${error.message}`);
  }
  try {
    await runCommand('kata', ['projects', 'show', project, '--json']);
  } catch (error) {
    throw invalid(configPath, 'execution.project', `kata project ${JSON.stringify(project)} is unavailable: ${error.message}`);
  }
}
```

Validation rules:

- `roadmap` and `execution` may be omitted and then receive their default object.
- `plane.project` and `kata.project` are trimmed non-empty strings.
- `completion` defaults to `landed` for every execution provider but is accepted only as `landed` or `pull_request`.
- Unknown keys at every object level are rejected to catch misspellings.
- Runtime checks are skipped when execution is `session` or `none`. Skills MUST use the default checked mode; `--no-runtime-check` exists only for offline inspection and deterministic tests.
- CLI syntax is `node resolve-config.mjs [--root DIR] [--no-runtime-check]`; unknown flags exit `2`, validation/runtime errors exit `1`, success prints exactly one JSON object.

Create `skills/tracking-providers/SKILL.md` with the authority table from the spec, the committed configuration schema, the exact resolver invocation, provider-qualified reference formats, and a rule that lifecycle skills must call the checked resolver before any Kata-backed repository mutation and branch on normalized output rather than reading JSON themselves.

- [ ] **Step 4: Run resolver tests and CLI smoke checks**

Run:

```bash
node --test tests/tracking-providers/test-resolve-config.mjs
node skills/tracking-providers/scripts/resolve-config.mjs --root . --no-runtime-check
```

Expected: tests PASS; CLI prints the default `file`/`session` object because this bootstrap repository is intentionally not configured yet.

- [ ] **Step 5: Commit the resolver**

```bash
jj commit \
  skills/tracking-providers/SKILL.md \
  skills/tracking-providers/scripts/resolve-config.mjs \
  tests/tracking-providers/test-resolve-config.mjs \
  -m "Add tracking provider configuration"
```

---

### Task 2: Idempotent Kata plan materialization

**Files:**
- Create: `skills/tracking-providers/scripts/materialize-plan.mjs`
- Create: `tests/tracking-providers/test-materialize-plan.mjs`
- Modify: `skills/tracking-providers/SKILL.md`

**Interfaces:**
- Consumes: `materializePlan({ root, planPath, config, runKata })` where the plan contains `# ... Implementation Plan`, `**Spec:**`, one generic `**Source:**` copied from a Plane outcome or derived by qualifying a file milestone with `file:`, and numbered `### Task N:` headings.
- Produces: `{ parent: { ref, created }, children: [{ task, ref, created }] }` and a CLI `node materialize-plan.mjs --root DIR --plan PATH`.
- Kata invocation uses `kata --project <name> create ... --json --idempotency-key <key>` and the parent/child relationship supported by Kata v0.16.0.

- [ ] **Step 1: Write plan parser and materialization tests**

Create `tests/tracking-providers/test-materialize-plan.mjs`:

```js
import assert from 'node:assert/strict';
import test from 'node:test';

import { parsePlan, materializePlan } from '../../skills/tracking-providers/scripts/materialize-plan.mjs';

const plan = `# Provider Example Implementation Plan

**Spec:** \`docs/project/specs/example.md\`

**Source:** plane:SJUP-12

### Task 1: Resolver
body

### Task 2: Skill integration
body
`;

test('parsePlan extracts stable task identities', () => {
  assert.deepEqual(parsePlan(plan), {
    title: 'Provider Example',
    spec: 'docs/project/specs/example.md',
    source: 'plane:SJUP-12',
    tasks: [
      { number: 1, title: 'Resolver' },
      { number: 2, title: 'Skill integration' },
    ],
  });
});

test('materialization creates one parent and one child per task with stable keys', async () => {
  const calls = [];
  const runKata = async (args) => {
    calls.push(args);
    const key = args[args.indexOf('--idempotency-key') + 1];
    return { short_id: key.endsWith(':parent') ? 'root' : `t${calls.length - 1}`, created: true };
  };

  const result = await materializePlan({
    root: '/repo',
    planPath: '/repo/docs/project/plans/example.md',
    markdown: plan,
    config: {
      execution: { provider: 'kata', project: 'sjujperpowers', completion: 'landed' },
    },
    runKata,
  });

  assert.equal(calls.length, 3);
  assert.match(calls[0].join(' '), /--meta sjujperpowers.source=plane:SJUP-12/);
  assert.ok(calls[1].includes('--parent'));
  assert.deepEqual(result.children.map(({ task }) => task), [1, 2]);
});

test('file roadmap source materializes through Kata without Plane', async () => {
  const calls = [];
  await materializePlan({
    root: '/repo',
    planPath: '/repo/docs/project/plans/file-backed.md',
    markdown: plan.replace('plane:SJUP-12', 'file:M1 — Provider framework'),
    config: {
      roadmap: { provider: 'file' },
      execution: { provider: 'kata', project: 'sjujperpowers', completion: 'landed' },
    },
    runKata: async (args) => {
      calls.push(args);
      return { short_id: calls.length === 1 ? 'root' : `t${calls.length - 1}`, created: true };
    },
  });

  assert.equal(calls.length, 3);
  assert.match(calls[0].join(' '), /--meta sjujperpowers.source=file:M1 — Provider framework/);
  assert.doesNotMatch(calls.flat().join(' '), /plane:/);
});
```

Add cases for duplicate task numbers, missing required headers, non-Kata execution provider, raw Kata output missing `short_id`, retry responses with `created: false`, and paths outside `root`.

- [ ] **Step 2: Run materialization tests and verify RED**

Run:

```bash
node --test tests/tracking-providers/test-materialize-plan.mjs
```

Expected: FAIL because `materialize-plan.mjs` does not exist.

- [ ] **Step 3: Implement parsing, idempotency, and normalized output**

Create `skills/tracking-providers/scripts/materialize-plan.mjs`. Use the plan's repository-relative path and SHA-256 to derive stable keys:

```js
function keyPrefix(project, relativePlan) {
  const digest = createHash('sha256')
    .update(`${project}\0${relativePlan}`)
    .digest('hex')
    .slice(0, 24);
  return `sjujperpowers:${digest}`;
}

export function parsePlan(markdown) {
  const title = requireMatch(markdown, /^# (.+) Implementation Plan$/m, 'implementation-plan title')[1];
  const spec = requireMatch(markdown, /^\*\*Spec:\*\* `([^`]+)`$/m, 'Spec header')[1];
  const source = requireMatch(markdown, /^\*\*Source:\*\* (.+)$/m, 'Source header')[1].trim();
  const tasks = [...markdown.matchAll(/^### Task (\d+): (.+)$/gm)].map((match) => ({
    number: Number(match[1]),
    title: match[2].trim(),
  }));
  assertUniqueOrderedTasks(tasks);
  return { title, spec, source, tasks };
}
```

Create the parent with title `<plan title>`, body containing exact spec and plan paths, metadata keys `sjujperpowers.plan`, `sjujperpowers.spec`, and `sjujperpowers.source`, and idempotency key `<prefix>:parent`. Create each child with title `Task N: <title>`, `--parent <parent short_id>`, the same plan/spec/source metadata plus `sjujperpowers.task=<N>`, and key `<prefix>:task:<N>`. The source is opaque: `plane:SJUP-12`, `file:M1 — Provider framework`, and `none (bootstrap)` all materialize identically when the independent execution provider is `kata`.

Normalize every Kata response to `{ ref: '<project>#<short_id>', created: Boolean(response.created) }`. Do not expose raw ULIDs to skills. On partial failure, throw an error whose JSON details include already normalized parent/children so retry evidence is preserved; stable idempotency keys make the next invocation safe.

- [ ] **Step 4: Run unit and CLI failure-path checks**

Run:

```bash
node --test tests/tracking-providers/test-materialize-plan.mjs
node skills/tracking-providers/scripts/materialize-plan.mjs \
  --root . \
  --plan docs/project/plans/2026-09-02-pluggable-tracking-providers.md
```

Expected: tests PASS; CLI exits `1` with `execution.provider must be kata` because bootstrap still uses defaults and therefore cannot accidentally create local Kata issues.

- [ ] **Step 5: Commit the materializer**

```bash
jj commit \
  skills/tracking-providers/SKILL.md \
  skills/tracking-providers/scripts/materialize-plan.mjs \
  tests/tracking-providers/test-materialize-plan.mjs \
  -m "Materialize plans into Kata"
```

---

### Task 3: Roadmap, spec, and plan activation

**Files:**
- Modify: `skills/roadmapping/SKILL.md`
- Modify: `skills/brainstorming/SKILL.md`
- Modify: `skills/writing-plans/SKILL.md`
- Modify: `skills/using-sjujperpowers/SKILL.md`
- Create: `evals/scenarios/tracking-providers-plane/story.md`
- Create: `evals/scenarios/tracking-providers-plane/setup.sh`
- Create: `evals/scenarios/tracking-providers-plane/post.sh`

**Interfaces:**
- Consumes: normalized tracking configuration and a provider-neutral source copied from the spec, such as `plane:SJUP-12` or `file:M1 — Provider framework`.
- Produces: a spec with its provider-specific header and a plan whose generic `**Source:**` carries the exact source reference, then an idempotent Kata materialization invocation after the plan commit.

- [ ] **Step 1: Add a failing Plane activation eval fixture**

Create an eval scenario whose fixture contains:

```json
{
  "version": 1,
  "roadmap": { "provider": "plane", "project": "Sjujperpowers" },
  "execution": { "provider": "session" }
}
```

The story asks the agent to orient and design work for existing outcome `plane:SJUP-12`. The deterministic `post.sh` must pass only when:

- the produced spec contains `**Outcome:** plane:SJUP-12`;
- no `docs/project/roadmap.md` was created or modified;
- the produced plan contains `**Source:** plane:SJUP-12`;
- the agent did not claim it created or updated Plane state.

Use the existing `evals/scenarios/*/{story.md,setup.sh,post.sh}` contract and `evals/lib/checks.sh` helpers rather than inventing a new runner.

- [ ] **Step 2: Run the eval setup/post backstop and verify the wrong fixture fails**

Run:

```bash
evals/run setup tracking-providers-plane
evals/run post tracking-providers-plane
```

Expected: post check FAIL before an agent session creates the required spec/plan, proving the assertions discriminate the missing behavior.

- [ ] **Step 3: Update roadmap and specification skills**

In `skills/roadmapping/SKILL.md`, add a first step that runs the checked tracking resolver before any roadmap/spec handoff mutation. If execution is `kata`, resolver success proves the executable, daemon, and configured project. Then branch on the independent roadmap provider:

```text
file  -> preserve Create, Revise, and Orient against docs/project/roadmap.md
plane -> require an existing plane:<identifier> reference; never write the file roadmap
none  -> report persistent roadmap state intentionally disabled and hand off
```

Document that Plane Community Edition modules group focused initiatives and linked work items represent cross-project efforts. Do not recommend Plane Initiatives.

In `skills/brainstorming/SKILL.md`, run the same checked resolver before creating or editing a spec, including when brainstorming is invoked directly without roadmapping. Replace the unconditional milestone lookup with provider-aware orientation. Plane-backed architectural specs use `**Outcome:** plane:<identifier>` immediately below the title; file-backed specs retain `**Milestone:**`; bootstrap work may use `**Outcome:** none (bootstrap)` with an explicit decision. Preserve the existing approval, self-review, and fileset-commit gates. A failed Kata preflight returns before any versioned artifact changes.

- [ ] **Step 4: Update plan writing and bootstrap guidance**

In `skills/writing-plans/SKILL.md`, run the checked resolver before creating or editing the plan, then:

- add mandatory `**Source:**` to the plan header;
- copy the exact Plane outcome, file-roadmap milestone, or `none (bootstrap)` value from the approved spec;
- after committing a Kata-backed plan, run:

```bash
node <tracking-providers skill dir>/scripts/materialize-plan.mjs \
  --root "$(jj root)" \
  --plan docs/project/plans/YYYY-MM-DD-<feature-name>.md
```

- report the normalized parent and child refs;
- preserve checkbox syntax only as plan readability/session input, not durable state.

In `skills/using-sjujperpowers/SKILL.md`, add the provider resolution step to the workflow overview and make clear that configuration absence retains current behavior.

- [ ] **Step 5: Exercise the eval scenario in a real harness session**

Run the setup command, perform the story in one supported harness with Sjujperpowers loaded, then run:

```bash
evals/run post tracking-providers-plane
```

Expected: PASS; exact Plane reference appears in spec and plan; no file roadmap exists.

- [ ] **Step 6: Commit roadmap activation behavior**

```bash
jj commit \
  skills/roadmapping/SKILL.md \
  skills/brainstorming/SKILL.md \
  skills/writing-plans/SKILL.md \
  skills/using-sjujperpowers/SKILL.md \
  evals/scenarios/tracking-providers-plane \
  -m "Route planning through tracking providers"
```

---

### Task 4: Kata execution lifecycle integration

**Files:**
- Modify: `skills/starting-a-change/SKILL.md`
- Modify: `skills/executing-plans/SKILL.md`
- Modify: `skills/subagent-driven-development/SKILL.md`
- Modify: `skills/finishing-a-change-stack/SKILL.md`
- Create: `evals/scenarios/tracking-providers-kata/story.md`
- Create: `evals/scenarios/tracking-providers-kata/setup.sh`
- Create: `evals/scenarios/tracking-providers-kata/post.sh`

**Interfaces:**
- Consumes: normalized Kata configuration and provider-qualified issue refs produced by Task 2.
- Produces: ordered claim/change/evidence/landing/close behavior without replacing controller todos or SDD recovery state.

- [ ] **Step 1: Add a failing Kata lifecycle eval fixture**

The setup creates a fixture repository with Kata selected and a fake `kata` executable first on `PATH`. The fake executable logs command arguments as JSON lines and returns deterministic JSON for `next`, `claim`, `comment`, and `close`.

The story asks the agent to start, execute, and finish one plan task, choosing `keep-as-is` first. `post.sh` must assert:

- `claim` appears before `fresh-change` repository mutation evidence;
- the Jujutsu description contains the qualified Kata ref;
- harness todo and `.sjujperpowers/sdd/<plan>/progress.md` state both exist;
- verification records a Kata comment containing test evidence;
- no `kata close` appears after `keep-as-is`.

A second fixture run chooses successful local landing and requires `close` only after the landing marker.

- [ ] **Step 2: Run post checks against deliberately wrong logs**

Run both setup/post modes with generated logs ordered incorrectly. Expected: each post check FAILS on its specific ordering assertion before skill edits.

- [ ] **Step 3: Integrate claim and Jujutsu association**

Update `skills/starting-a-change/SKILL.md` so Kata-backed work performs:

```bash
CONFIG_JSON="$(node <tracking-providers skill dir>/scripts/resolve-config.mjs --root "$(jj root)")"
kata --project "$KATA_PROJECT" claim "$ISSUE_REF" --json
<starting-a-change skill dir>/scripts/fresh-change
CHANGE_ID="$(jj log -r @ --no-graph -T 'change_id')"
jj describe -m "$TASK_DESCRIPTION

Kata: $QUALIFIED_ISSUE_REF"
kata --project "$KATA_PROJECT" comment "$ISSUE_REF" \
  --body "Associated Jujutsu change: $CHANGE_ID" --json
```

The skill may select `kata next --json` only when no issue ref was provided. It must never force a claim. Claim failure stops before `fresh-change`; change setup failure adds a Kata comment describing the failed association and leaves the claim visible for deliberate recovery.

- [ ] **Step 4: Integrate controller and SDD lifecycle boundaries**

Update `skills/executing-plans/SKILL.md` so harness todos remain mandatory and Kata state changes occur at the same plan-task boundaries.

Update `skills/subagent-driven-development/SKILL.md` so:

- its per-plan workspace, brief, report, review-package, and `progress.md` mechanisms remain mandatory;
- Kata state owns only unclaimed/active/blocked/completed across sessions;
- `progress.md` owns review round, rulings, and resume position within the active task;
- resume compares both sources and stops on contradictions such as a closed issue with an unfinished review loop;
- blockers use a substantive `kata comment` and a `blocked` label without manufacturing a completion.

- [ ] **Step 5: Integrate evidence and post-landing close ordering**

Update `skills/finishing-a-change-stack/SKILL.md` to enforce this provider-aware sequence:

```text
verify -> kata comment with evidence -> shape stack -> choose action
-> perform landing/publication -> kata close -> render Plane roll-up
```

For `completion=landed`, only a successful landing permits:

```bash
kata --project "$KATA_PROJECT" close "$ISSUE_REF" \
  --reason done \
  --message "<issue-specific completed scope; Jujutsu change $CHANGE_ID landed as $COMMIT_ID>" \
  --commit "$COMMIT_ID" \
  --test "$VERIFICATION_COMMAND" \
  --json
```

For `completion=pull_request`, require a successfully created PR URL and use `--pr`. `keep-as-is`, discarded work, failed land, and failed publication leave the issue open. Close the plan root only after all child issues and local acceptance criteria are complete. Render one curated Plane summary but do not apply it automatically or close the Plane outcome.

- [ ] **Step 6: Run the lifecycle evals**

Exercise both scenarios in a supported harness and run their post checks.

Expected: keep-as-is PASS with no close; landed PASS with the close after the landing marker; harness todo and SDD recovery assertions PASS in both.

- [ ] **Step 7: Commit execution lifecycle behavior**

```bash
jj commit \
  skills/starting-a-change/SKILL.md \
  skills/executing-plans/SKILL.md \
  skills/subagent-driven-development/SKILL.md \
  skills/finishing-a-change-stack/SKILL.md \
  evals/scenarios/tracking-providers-kata \
  -m "Integrate Kata execution lifecycle"
```

---

### Task 5: Provider documentation and regression verification

**Files:**
- Modify: `README.md`
- Modify: `docs/testing.md`
- Modify: `skills/tracking-providers/SKILL.md`

**Interfaces:**
- Consumes: completed provider scripts and skill contracts from Tasks 1-4.
- Produces: one documented operating model and reproducible verification commands.

- [ ] **Step 1: Document the adopted workflow**

Add a concise README section with:

```text
Plane outcome -> versioned spec -> versioned plan -> Kata issues
-> Jujutsu changes/evidence -> curated Plane roll-up
```

Document the two independent provider slots, default behavior, one Plane workspace, Plane project boundaries, Community Edition modules, linked work items for cross-project efforts, Kata project-per-repository convention, and the rule that terminal or workspace-manager sessions are UI groupings while Jujutsu workspaces are concurrent code changes.

Add complete configuration examples for default, Plane+Kata, and provider-disabled repositories. Link the design spec and `tracking-providers` skill instead of duplicating lifecycle command detail.

- [ ] **Step 2: Document deterministic and eval checks**

Update `docs/testing.md` with:

```bash
node --test tests/tracking-providers/test-resolve-config.mjs
node --test tests/tracking-providers/test-materialize-plan.mjs
evals/run setup tracking-providers-plane
evals/run post tracking-providers-plane
evals/run setup tracking-providers-kata
evals/run post tracking-providers-kata
```

State that eval post checks are deterministic backstops but require a real harness run between setup and post for behavioral proof.

- [ ] **Step 3: Run deterministic provider tests and existing affected suites**

Run:

```bash
node --test tests/tracking-providers/test-resolve-config.mjs
node --test tests/tracking-providers/test-materialize-plan.mjs
bash tests/starting-a-change/test-fresh-change.sh
bash tests/claude-code/test-sdd-workspace.sh
bash tests/writing-skills/test-render-graphs.sh
```

Expected: all commands exit `0`.

- [ ] **Step 4: Run provider-free smoke behavior**

From the repository root with no `.sjujperpowers/config.json`:

```bash
node skills/tracking-providers/scripts/resolve-config.mjs --root . --no-runtime-check
```

Expected JSON contains roadmap `file`, execution `session`, completion `landed`, and `configPath: null`. Confirm roadmapping and starting-a-change still follow their original paths in a short harness session.

- [ ] **Step 5: Commit documentation**

```bash
jj commit README.md docs/testing.md skills/tracking-providers/SKILL.md \
  -m "Document tracking provider workflow"
```
