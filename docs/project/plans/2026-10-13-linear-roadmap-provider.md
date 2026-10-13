# Linear Roadmap Provider Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use sjujperpowers:subagent-driven-development (recommended) or sjujperpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add `linear` as a reference-only roadmap provider next to `plane`, behind a small roadmap-provider registry that one contract test holds every external provider to.

**Architecture:** A new `roadmap-providers.mjs` defines one entry per roadmap provider (`file`, `plane`, `linear`, `none`) with its own `normalize`; `resolve-config.mjs` keeps the shared roadmap checks and dispatches to the entry. External entries also carry `fields`, `referencePattern`, and `exampleReference`, which the contract test and the docs use. `materialize-plan.mjs` already treats `**Source:**` as opaque and does not change.

**Tech Stack:** Node.js 22 ES modules with `node:test`; Bash and the `evals/` harness; Jujutsu.

**Spec:** `docs/project/specs/2026-10-13-linear-roadmap-provider-design.md`

**Source:** plane:SJUP-3

## Global Constraints

- Linear is reference-only: no skill, script, or test calls the Linear API or a Linear MCP tool.
- Plane's resolved output and every Plane, `file`, `none`, and execution error message stay exactly as today; the only changed message outside Linear is `roadmap.provider must be one of: file, plane, linear, none`.
- The no-config default stays `{ "provider": "file" }`. This repository's `.sjujperpowers/config.json` is not changed.
- `team` must match `^[A-Z][A-Z0-9]*$` after trimming; lowercase is rejected, never uppercased.
- `materialize-plan.mjs` is not changed, and nothing checks a plan's `Source` against the configured provider.
- Scripts stay dependency-free (Node built-ins only). New scenario shell files follow the existing scenario convention (no shebang; `evals/run` sources them) and pass `shellcheck -s bash --severity=warning`.
- The September tracking-provider spec and plan are not edited.
- Every test and eval check removes the temp directories it creates. Every manual behavioral run ends with `evals/run teardown <fixture-dir>`, after post and also when the run fails or is abandoned.
- Skill edits follow sjujperpowers:writing-skills: run the baseline before writing the skill text, then confirm the agent complies.
- Behavioral runs are headless `omp -p` sessions run by the controller (implementers run deterministic tests only). The session loads a copy of the stack's `skills/` directory, placed outside the repository (for example under `/tmp/evals-out/`), through the fixture's `.omp/config.yml` (`skills: { customDirectories: [<copy>] }`), with `.omp/` added to the fixture's `.git/info/exclude`. Run `omp` with `--no-extensions` inside `unshare -rm` with an empty directory bind-mounted over this repository's checkout, so the agent can read neither the live repository nor the installed plugin's copies of the skills. The first turn is `omp -p "<story's exact message>"` in the fixture; each later turn is `omp -c -p "<reply>"` with the story's scripted replies. Before grading, confirm from the transcript that the skill files read came from the copy; if any came from `~/.omp/plugins/…` or the live checkout, stop, record the run as invalid, and report it instead of grading.
- Commit by fileset (`jj commit <paths> -m …`); never a bare `jj commit`.
- Out of scope: Linear write-side sync, source validation, multi-team configuration, plugin release or pin bumps, pushes.

## File Structure

| Path | Responsibility |
|---|---|
| `skills/tracking-providers/scripts/roadmap-providers.mjs` | Roadmap provider registry: per-provider normalization, fields, reference patterns, examples |
| `skills/tracking-providers/scripts/resolve-config.mjs` | Shared roadmap checks; dispatch to the registry |
| `tests/tracking-providers/test-resolve-config.mjs` | Linear normalization and exact rejection messages; existing cases unchanged except the removed reserved-`linear` case |
| `tests/tracking-providers/test-roadmap-providers.mjs` | Contract checks every external provider passes, including the plan round-trip |
| `evals/scenarios/tracking-providers-linear/` | Behavioral scenario: Linear outcome flows into spec and plan |
| `tests/evals/test-scenario-discrimination.sh` | The new scenario's `post()` passes a good outcome and fails two bad ones |
| `skills/{tracking-providers,roadmapping,brainstorming,writing-plans,finishing-a-change-stack,using-sjujperpowers}/SKILL.md`, `README.md`, `docs/testing.md`, `evals/README.md` | Documentation of the Linear provider |

---

### Task 1: Roadmap provider registry and Linear configuration

**Files:**
- Create: `skills/tracking-providers/scripts/roadmap-providers.mjs`
- Create: `tests/tracking-providers/test-roadmap-providers.mjs`
- Modify: `skills/tracking-providers/scripts/resolve-config.mjs:9-10,72-92`
- Modify: `tests/tracking-providers/test-resolve-config.mjs:64-65,155,178-179`

**Interfaces:**
- Consumes: `normalizeConfig(raw, configPath)` from `resolve-config.mjs`; `parsePlan(markdown)` and `materializePlan({ root, planPath, markdown, config, runKata })` from `materialize-plan.mjs` (unchanged).
- Produces: `roadmap-providers.mjs` exports `ROADMAP_PROVIDERS` (frozen array in order `file`, `plane`, `linear`, `none`), `EXTERNAL_ROADMAP_PROVIDERS` (entries with a `referencePattern`: `plane`, `linear`), `ROADMAP_KEYS` (`['provider', 'project', 'team']`), and `roadmapProvider(name)` (entry or `undefined`). Each entry has `name` and `normalize(raw, invalid)`, where `invalid(field, message)` returns the resolver's `Error`. External entries add `fields: { required: string[], optional: string[] }`, `referencePattern: RegExp`, `exampleReference: string`. Resolved Linear roadmap: `{ provider: 'linear', team }` plus `project` only when configured.

- [ ] **Step 1: Write the failing tests**

Apply this change to `tests/tracking-providers/test-resolve-config.mjs`:

```diff
--- a/tests/tracking-providers/test-resolve-config.mjs
+++ b/tests/tracking-providers/test-resolve-config.mjs
@@ -63,6 +63,30 @@
   );
 });
 
+test('linear configuration is normalized with and without a project', () => {
+  assert.deepEqual(
+    normalizeConfig(
+      { version: 1, roadmap: { provider: 'linear', team: ' CEW ' } },
+      '/repo/config.json',
+    ).roadmap,
+    { provider: 'linear', team: 'CEW' },
+  );
+  assert.deepEqual(
+    normalizeConfig(
+      { version: 1, roadmap: { project: ' Pilot ', team: 'CEW2', provider: 'linear' } },
+      '/repo/config.json',
+    ).roadmap,
+    { provider: 'linear', team: 'CEW2', project: 'Pilot' },
+  );
+});
+
+test('unknown roadmap provider error lists every registered provider', () => {
+  assert.throws(
+    () => normalizeConfig({ version: 1, roadmap: { provider: 'jira' } }, '/repo/config.json'),
+    { message: '/repo/config.json: roadmap.provider must be one of: file, plane, linear, none' },
+  );
+});
+
 test('roadmap and execution slots remain independent', () => {
   assert.deepEqual(
     normalizeConfig(
@@ -152,7 +176,6 @@
   ['escaping docs root', { version: 1, docsRoot: '../project' }, 'docsRoot'],
   ['backslash docs root', { version: 1, docsRoot: 'docs\\project' }, 'docsRoot'],
   ['unknown roadmap provider', { version: 1, roadmap: { provider: 'jira' } }, 'roadmap.provider'],
-  ['reserved linear provider', { version: 1, roadmap: { provider: 'linear', project: 'x' } }, 'roadmap.provider'],
   ['missing Plane project', { version: 1, roadmap: { provider: 'plane' } }, 'roadmap.project'],
   ['wrong Plane project type', { version: 1, roadmap: { provider: 'plane', project: 3 } }, 'roadmap.project'],
   ['project on file provider', { version: 1, roadmap: { provider: 'file', project: 'x' } }, 'roadmap.project'],
@@ -177,6 +200,27 @@
   });
 }
 
+for (const [name, roadmap, message] of [
+  ['missing Linear team', { provider: 'linear' }, 'roadmap.team must be a non-empty string'],
+  ['blank Linear team', { provider: 'linear', team: '  ' }, 'roadmap.team must be a non-empty string'],
+  ['wrong Linear team type', { provider: 'linear', team: 3 }, 'roadmap.team must be a non-empty string'],
+  ['lowercase Linear team', { provider: 'linear', team: 'cew' }, 'roadmap.team must be an uppercase Linear team key such as CEW'],
+  ['digit-first Linear team', { provider: 'linear', team: '9AB' }, 'roadmap.team must be an uppercase Linear team key such as CEW'],
+  ['punctuated Linear team', { provider: 'linear', team: 'C-W' }, 'roadmap.team must be an uppercase Linear team key such as CEW'],
+  ['blank Linear project', { provider: 'linear', team: 'CEW', project: '' }, 'roadmap.project must be a non-empty string'],
+  ['team on Plane provider', { provider: 'plane', project: 'x', team: 'CEW' }, 'roadmap.team is not valid for provider plane'],
+  ['team on file provider', { provider: 'file', team: 'CEW' }, 'roadmap.team is not valid for provider file'],
+  ['team on none provider', { provider: 'none', team: 'CEW' }, 'roadmap.team is not valid for provider none'],
+  ['unknown roadmap key', { provider: 'linear', team: 'CEW', workspace: 'cewlabs' }, 'roadmap.workspace is not supported'],
+]) {
+  test(`${name} fails with its exact message`, () => {
+    assert.throws(
+      () => normalizeConfig({ version: 1, roadmap }, '/repo/config.json'),
+      { message: `/repo/config.json: ${message}` },
+    );
+  });
+}
+
 test('Kata preflight checks health before the configured project', async () => {
   const calls = [];
 
```

Create `tests/tracking-providers/test-roadmap-providers.mjs`:

```js
import assert from 'node:assert/strict';
import test from 'node:test';

import {
  materializePlan,
  parsePlan,
} from '../../skills/tracking-providers/scripts/materialize-plan.mjs';
import { normalizeConfig } from '../../skills/tracking-providers/scripts/resolve-config.mjs';
import { EXTERNAL_ROADMAP_PROVIDERS } from '../../skills/tracking-providers/scripts/roadmap-providers.mjs';

const CONFIG_PATH = '/repo/.sjujperpowers/config.json';

const MINIMAL_ROADMAPS = {
  plane: { provider: 'plane', project: 'Example' },
  linear: { provider: 'linear', team: 'CEW' },
};

function planWithSource(source) {
  return `# Provider Contract Implementation Plan

**Spec:** \`docs/project/specs/contract.md\`

**Source:** ${source}

### Task 1: First

Details.

### Task 2: Second

Details.
`;
}

function recordingKata(calls) {
  return async (args) => {
    calls.push(args);
    const key = args[args.indexOf('--idempotency-key') + 1];
    return { issue: { short_id: key.endsWith(':parent') ? 'root' : `t${calls.length - 1}` } };
  };
}

function sourceMetadata(args) {
  return args
    .filter((_, index) => args[index - 1] === '--meta')
    .find((value) => value.startsWith('sjujperpowers.source='));
}

test('every external provider has a minimal contract configuration', () => {
  assert.deepEqual(
    EXTERNAL_ROADMAP_PROVIDERS.map(({ name }) => name).sort(),
    Object.keys(MINIMAL_ROADMAPS).sort(),
  );
});

for (const provider of EXTERNAL_ROADMAP_PROVIDERS) {
  const minimal = MINIMAL_ROADMAPS[provider.name];

  test(`${provider.name}: minimal configuration resolves and is stable`, () => {
    const once = normalizeConfig({ version: 1, roadmap: minimal }, CONFIG_PATH).roadmap;
    const twice = normalizeConfig({ version: 1, roadmap: once }, CONFIG_PATH).roadmap;
    assert.equal(once.provider, provider.name);
    assert.deepEqual(twice, once);
  });

  for (const field of provider.fields.required) {
    test(`${provider.name}: missing ${field} fails and names it`, () => {
      const { [field]: _omitted, ...roadmap } = minimal;
      assert.throws(
        () => normalizeConfig({ version: 1, roadmap }, CONFIG_PATH),
        new RegExp(`: roadmap\\.${field} `),
      );
    });
  }

  test(`${provider.name}: example reference matches only its own pattern`, () => {
    assert.match(provider.exampleReference, provider.referencePattern);
    for (const other of EXTERNAL_ROADMAP_PROVIDERS) {
      if (other !== provider) {
        assert.doesNotMatch(provider.exampleReference, other.referencePattern);
      }
    }
  });

  test(`${provider.name}: example reference round-trips through plan materialization`, async () => {
    const markdown = planWithSource(provider.exampleReference);
    assert.equal(parsePlan(markdown).source, provider.exampleReference);

    const calls = [];
    await materializePlan({
      root: '/repo',
      planPath: '/repo/docs/project/plans/contract.md',
      markdown,
      config: normalizeConfig(
        {
          version: 1,
          roadmap: minimal,
          execution: { provider: 'kata', project: 'sjujperpowers' },
        },
        CONFIG_PATH,
      ),
      runKata: recordingKata(calls),
    });

    assert.equal(calls.length, 3);
    for (const args of calls) {
      assert.equal(sourceMetadata(args), `sjujperpowers.source=${provider.exampleReference}`);
    }
  });
}
```

Create `skills/tracking-providers/scripts/roadmap-providers.mjs` now, because the contract test imports it; the resolver does not use it until Step 3:

```js
// Roadmap providers: one entry per provider, in documentation order.
// normalize(raw, invalid) receives a roadmap object that already passed the
// resolver's shared checks (object, known keys, registered provider) and
// returns the resolved roadmap object. invalid(field, message) builds the
// resolver's path-qualified error.

const TEAM_KEY = /^[A-Z][A-Z0-9]*$/;

function requireString(raw, field, invalid) {
  const value = raw[field];
  if (typeof value !== 'string' || value.trim() === '') {
    throw invalid(`roadmap.${field}`, 'must be a non-empty string');
  }
  return value.trim();
}

function rejectFields(raw, fields, provider, invalid) {
  for (const field of fields) {
    if (raw[field] !== undefined) {
      throw invalid(`roadmap.${field}`, `is not valid for provider ${provider}`);
    }
  }
}

const file = {
  name: 'file',
  normalize(raw, invalid) {
    rejectFields(raw, ['project', 'team'], 'file', invalid);
    return { provider: 'file' };
  },
};

const plane = {
  name: 'plane',
  fields: { required: ['project'], optional: [] },
  referencePattern: /^plane:[A-Z0-9]+-[1-9][0-9]*$/,
  exampleReference: 'plane:SJUP-12',
  normalize(raw, invalid) {
    rejectFields(raw, ['team'], 'plane', invalid);
    return { provider: 'plane', project: requireString(raw, 'project', invalid) };
  },
};

const linear = {
  name: 'linear',
  fields: { required: ['team'], optional: ['project'] },
  referencePattern: /^linear:[A-Z][A-Z0-9]*-[1-9][0-9]*$/,
  exampleReference: 'linear:CEW-123',
  normalize(raw, invalid) {
    const team = requireString(raw, 'team', invalid);
    if (!TEAM_KEY.test(team)) {
      throw invalid('roadmap.team', 'must be an uppercase Linear team key such as CEW');
    }
    const roadmap = { provider: 'linear', team };
    if (raw.project !== undefined) {
      roadmap.project = requireString(raw, 'project', invalid);
    }
    return roadmap;
  },
};

const none = {
  name: 'none',
  normalize(raw, invalid) {
    rejectFields(raw, ['project', 'team'], 'none', invalid);
    return { provider: 'none' };
  },
};

export const ROADMAP_PROVIDERS = Object.freeze([file, plane, linear, none]);

export const EXTERNAL_ROADMAP_PROVIDERS = Object.freeze(
  ROADMAP_PROVIDERS.filter((provider) => provider.referencePattern !== undefined),
);

export const ROADMAP_KEYS = Object.freeze(['provider', 'project', 'team']);

export function roadmapProvider(name) {
  return ROADMAP_PROVIDERS.find((provider) => provider.name === name);
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `node --test tests/tracking-providers/test-resolve-config.mjs; node --test tests/tracking-providers/test-roadmap-providers.mjs`
Expected: `test-resolve-config.mjs` reports `# fail 13` (the two new normalization tests and all eleven exact-message cases; `missing Linear team` fails because the old resolver names `roadmap.provider`). `test-roadmap-providers.mjs` reports `# fail 3` (`linear` minimal configuration, missing `team`, and the Linear round-trip; the Plane cases and both pattern cases pass).

- [ ] **Step 3: Dispatch roadmap normalization to the registry**

Apply this change to `skills/tracking-providers/scripts/resolve-config.mjs`:

```diff
--- a/skills/tracking-providers/scripts/resolve-config.mjs
+++ b/skills/tracking-providers/scripts/resolve-config.mjs
@@ -7,6 +7,8 @@
 import { fileURLToPath } from 'node:url';
 import { promisify } from 'node:util';
 
+import { ROADMAP_KEYS, ROADMAP_PROVIDERS, roadmapProvider } from './roadmap-providers.mjs';
+
 const execFile = promisify(execFileCallback);
 const DEFAULT_DOCS_ROOT = 'docs/project';
 
@@ -72,23 +74,14 @@
 function normalizeRoadmap(raw, configPath) {
   if (raw === undefined) return { provider: 'file' };
   if (!isObject(raw)) throw invalid(configPath, 'roadmap', 'must be an object');
-  rejectUnknownKeys(raw, ['provider', 'project'], configPath, 'roadmap');
-
-  const provider = raw.provider;
-  if (!['file', 'plane', 'none'].includes(provider)) {
-    throw invalid(configPath, 'roadmap.provider', 'must be one of: file, plane, none');
-  }
+  rejectUnknownKeys(raw, ROADMAP_KEYS, configPath, 'roadmap');
 
-  if (provider === 'plane') {
-    return {
-      provider,
-      project: requireProject(raw.project, configPath, 'roadmap.project'),
-    };
-  }
-  if (raw.project !== undefined) {
-    throw invalid(configPath, 'roadmap.project', `is not valid for provider ${provider}`);
+  const provider = roadmapProvider(raw.provider);
+  if (provider === undefined) {
+    const names = ROADMAP_PROVIDERS.map(({ name }) => name).join(', ');
+    throw invalid(configPath, 'roadmap.provider', `must be one of: ${names}`);
   }
-  return { provider };
+  return provider.normalize(raw, (field, message) => invalid(configPath, field, message));
 }
 
 function normalizeExecution(raw, configPath) {
```

`requireProject` stays: `normalizeExecution` still uses it for `execution.project`.

- [ ] **Step 4: Run the tracking-provider suite to verify it passes**

Run: `for f in tests/tracking-providers/*.mjs; do node --test "$f" || exit 1; done; bash tests/tracking-providers/test-config-tracking.sh`
Expected: `test-materialize-plan.mjs` 15 pass, `test-resolve-config.mjs` 54 pass, `test-roadmap-providers.mjs` 9 pass, `test-symlinked-cli.mjs` 2 pass, all `# fail 0`; then `tracking provider config ignore rules: pass`. Run each file separately: `node --test tests/tracking-providers/` with a directory argument fails to load.

- [ ] **Step 5: Smoke the CLI**

Run:
```bash
T=$(mktemp -d) && mkdir "$T/.sjujperpowers" \
  && printf '{"version":1,"roadmap":{"provider":"linear","team":"CEW"},"execution":{"provider":"session"}}' > "$T/.sjujperpowers/config.json" \
  && node skills/tracking-providers/scripts/resolve-config.mjs --root "$T"; \
  printf '{"version":1,"roadmap":{"provider":"linear","team":"cew"}}' > "$T/.sjujperpowers/config.json"; \
  node skills/tracking-providers/scripts/resolve-config.mjs --root "$T"; echo "exit=$?"; rm -rf "$T"
```
Expected: first a JSON line containing `"roadmap":{"provider":"linear","team":"CEW"}`; then `<dir>/.sjujperpowers/config.json: roadmap.team must be an uppercase Linear team key such as CEW` and `exit=1`.

- [ ] **Step 6: Commit**

```bash
jj commit skills/tracking-providers/scripts/roadmap-providers.mjs skills/tracking-providers/scripts/resolve-config.mjs tests/tracking-providers/test-resolve-config.mjs tests/tracking-providers/test-roadmap-providers.mjs -m "Add Linear roadmap provider behind a provider registry"
```

### Task 2: Linear behavioral scenario and baseline

**Files:**
- Create: `evals/scenarios/tracking-providers-linear/setup.sh`
- Create: `evals/scenarios/tracking-providers-linear/checks.sh`
- Create: `evals/scenarios/tracking-providers-linear/story.md`
- Modify: `tests/evals/test-scenario-discrimination.sh:158-159`
- Modify: `evals/README.md:45-46`

**Interfaces:**
- Consumes: Task 1's resolver accepting `{"provider": "linear", "team": "DEMO"}`; the `evals/lib/fixtures.sh` builders `_init_repo`, `_commit`, `_bookmark_main_at_parent`; the `evals/lib/checks.sh` verbs.
- Produces: scenario `tracking-providers-linear` (status `draft`) with fixed paths `docs/project/specs/2026-09-02-health-report-design.md` and `docs/project/plans/2026-09-02-health-report.md` and outcome `linear:DEMO-12`.

- [ ] **Step 1: Write the failing discrimination cases**

Apply this change to `tests/evals/test-scenario-discrimination.sh`:

```diff
--- a/tests/evals/test-scenario-discrimination.sh
+++ b/tests/evals/test-scenario-discrimination.sh
@@ -157,6 +157,28 @@
 fx=$(fixture $s); (cd "$fx" && plane_provider_outcome 'plane:DEMO-12'); expect good $s "$fx"
 fx=$(fixture $s); (cd "$fx" && plane_provider_outcome 'DEMO-12'); expect bad $s "$fx"
 
+# --- tracking-providers-linear: provider-qualified source propagation
+linear_provider_outcome() {
+  local outcome=$1 source=$2
+  mkdir -p docs/project/specs docs/project/plans
+  cat > docs/project/specs/2026-09-02-health-report-design.md <<EOF
+# Health Report Design
+
+**Outcome:** $outcome
+EOF
+  cat > docs/project/plans/2026-09-02-health-report.md <<EOF
+# Health Report Implementation Plan
+
+**Spec:** \`docs/project/specs/2026-09-02-health-report-design.md\`
+
+**Source:** $source
+EOF
+}
+s=tracking-providers-linear
+fx=$(fixture $s); (cd "$fx" && linear_provider_outcome 'linear:DEMO-12' 'linear:DEMO-12'); expect good $s "$fx"
+fx=$(fixture $s); (cd "$fx" && linear_provider_outcome 'linear:DEMO-12' 'DEMO-12'); expect bad $s "$fx"
+fx=$(fixture $s); (cd "$fx" && linear_provider_outcome 'plane:DEMO-12' 'plane:DEMO-12'); expect bad $s "$fx"
+
 # --- tracking-providers-kata: keep-as-is preserves open execution state
 kata_cmd() { PATH="$PWD/.test-bin:$PATH" kata --project sjujperpowers "$@"; }
 kata_keep_good() {
```

- [ ] **Step 2: Run the discrimination suite to verify it fails**

Run: `bash tests/evals/test-scenario-discrimination.sh 2>&1 | grep -E 'tracking-providers-linear|STATUS'`
Expected: `STATUS: FAILED`, because `evals/run setup tracking-providers-linear` finds no scenario.

- [ ] **Step 3: Write the scenario**

Create `evals/scenarios/tracking-providers-linear/setup.sh`:

```bash
setup() {
  _init_repo "$1"
  mkdir -p .sjujperpowers
  cat > .sjujperpowers/config.json <<'EOF'
{
  "version": 1,
  "roadmap": {
    "provider": "linear",
    "team": "DEMO"
  },
  "execution": {
    "provider": "session"
  }
}
EOF
  cat > README.md <<'EOF'
# Demo Product

A small command-line application.
EOF
  _commit "initial project"
  _bookmark_main_at_parent
}
```

Create `evals/scenarios/tracking-providers-linear/checks.sh`:

```bash
SPEC='docs/project/specs/2026-09-02-health-report-design.md'
PLAN='docs/project/plans/2026-09-02-health-report.md'

pre() {
  jj-repo
  jj-bookmark-exists main
  file-exists .sjujperpowers/config.json
  file-contains .sjujperpowers/config.json '"provider": "linear"'
  not file-exists docs/project/roadmap.md
  not file-exists "$SPEC"
  not file-exists "$PLAN"
}

post() {
  file-exists "$SPEC"
  file-contains "$SPEC" '^\*\*Outcome:\*\* linear:DEMO-12$'
  file-exists "$PLAN"
  file-contains "$PLAN" '^\*\*Source:\*\* linear:DEMO-12$'
  not file-exists docs/project/roadmap.md
  command-succeeds "! jj file list -r main | grep -qx -- '$SPEC'"
  command-succeeds "! jj file list -r main | grep -qx -- '$PLAN'"
}
```

Create `evals/scenarios/tracking-providers-linear/story.md`:

````markdown
---
id: tracking-providers-linear
title: Linear roadmap references flow into specs and plans without a file roadmap
status: draft
tags: tracking-providers, roadmapping, brainstorming, writing-plans
---

You are planning a small health-report command in a repository configured with
a Linear roadmap provider for team `DEMO` and session execution. The existing
external outcome is `linear:DEMO-12`.

When the agent is ready for input, type this exact message:

"Use existing Linear outcome linear:DEMO-12 to design and plan a health-report
command. This is architectural. Save the design as
docs/project/specs/2026-09-02-health-report-design.md and the plan as
docs/project/plans/2026-09-02-health-report.md. Do not implement it or
change Linear."

How to behave:

- Answer reasonable product questions with the smallest boring command that
  prints one JSON object containing `status: ok`.
- Approve the in-chat design when it carries the exact Linear outcome and does
  not propose a local roadmap.
- When asked to review the committed written spec, reply "spec approved; write
  the implementation plan."
- When offered an execution choice, stop the run without choosing one.
- Do not mention `.sjujperpowers/config.json`, roadmap files, provider defaults,
  Plane, or Kata unless the agent brings them up first.

## Acceptance Criteria

- The agent resolves the repository's tracking configuration before writing.
- The spec contains `**Outcome:** linear:DEMO-12`.
- The plan contains `**Source:** linear:DEMO-12`.
- No `docs/project/roadmap.md` is created.
- The agent does not claim it created, edited, synchronized, or closed Linear
  state, and does not call a Linear API or MCP tool.
- The agent stops after planning and does not implement the command.
````

Apply this change to `evals/README.md`:

```diff
--- a/evals/README.md
+++ b/evals/README.md
@@ -43,6 +43,7 @@
 | `sdd-re-review-scoped` | mid-loop resume, scoped re-review | same name |
 | `sdd-same-plan-resume` | ledger prevents re-dispatching Task 1 | same name |
 | `tracking-providers-plane` | Plane outcome references flow into specs and plans without a file roadmap | new |
+| `tracking-providers-linear` | Linear outcome references flow into specs and plans without a file roadmap | new |
 | `tracking-providers-kata` | checked preflight, named-plan recovery, claim-before-association, and keep-open completion | new |
 | `tracking-providers-kata-landed` | landing-before-close ordering, child-before-root close, and delayed recovery cleanup | new |
 | `verifying-by-risk-protected-stack` | policy from local `main`, whole-stack range, protected override, blocked without a different-family verifier | new |
```

- [ ] **Step 4: Run the discrimination suite and lint to verify they pass**

Run: `bash tests/evals/test-scenario-discrimination.sh 2>&1 | grep -E 'tracking-providers-(plane|linear)|STATUS'; shellcheck -s bash --severity=warning evals/scenarios/tracking-providers-linear/*.sh; shellcheck --severity=warning --external-sources --source-path=SCRIPTDIR tests/evals/test-scenario-discrimination.sh`
Expected: `[PASS] tracking-providers-linear good outcome passes (7 checks)`, two `[PASS] tracking-providers-linear bad outcome caught` lines (one on the plan's `Source`, one on the spec's `Outcome`), the two unchanged Plane lines, `STATUS: PASSED`, and no shellcheck output.

- [ ] **Step 5: Commit**

```bash
jj commit evals/scenarios/tracking-providers-linear tests/evals/test-scenario-discrimination.sh evals/README.md -m "Add Linear tracking-provider behavioral scenario"
```

- [ ] **Step 6: Run the baseline (RED) with the current skill text (controller)**

Copy the stack's `skills/` directory (Task 1 code, skill text not yet updated) outside the repository. Run `evals/run setup tracking-providers-linear`, write the fixture's `.omp/config.yml` pointing `customDirectories` at the copy, add `.omp/` to `.git/info/exclude`, then play the story as headless `omp -p` turns. Run `evals/run post tracking-providers-linear <fixture-dir>` and `evals/run teardown <fixture-dir>`.
Expected: record the post result and, from the transcript, where the agent stalled or improvised: for example, treating `linear` as unsupported because tracking-providers says it is reserved, or inventing an Outcome format. If the baseline passes post and every acceptance criterion, record that; Task 3 still removes the "reserved but unsupported" line that contradicts the resolver.

### Task 3: Linear provider documentation

**Files:**
- Modify: `skills/tracking-providers/SKILL.md:22,66-69,104,110,132,149`
- Modify: `skills/roadmapping/SKILL.md:10,66`
- Modify: `skills/brainstorming/SKILL.md:99,212`
- Modify: `skills/writing-plans/SKILL.md:75,87,167`
- Modify: `skills/finishing-a-change-stack/SKILL.md:49,182`
- Modify: `skills/using-sjujperpowers/SKILL.md:36`
- Modify: `README.md:97,159`
- Modify: `docs/testing.md:41,44,48`

**Interfaces:**
- Consumes: Task 1's configuration contract (`team` required, optional `project`, references `linear:<TEAM>-<n>`); Task 2's scenario name.
- Produces: documentation only.

- [ ] **Step 1: Update the tracking-providers skill**

````diff
--- a/skills/tracking-providers/SKILL.md
+++ b/skills/tracking-providers/SKILL.md
@@ -19,7 +19,7 @@
 | SDD review rounds, briefs, reports, recovery; rulings are authored here and retained in the committed `<plan>-rulings.md` | Per-plan SDD workspace |
 | Implementation and landing history | Jujutsu |
 
-Roadmap and execution providers are independent. `file + kata` is as valid as `plane + kata`; Kata never requires Plane.
+Roadmap and execution providers are independent. `file + kata` is as valid as `plane + kata` or `linear + kata`; Kata never requires Plane or Linear.
 
 ## Configuration
 
@@ -63,10 +63,21 @@
 Supported roadmap providers:
 
 - `file` — `docs/project/roadmap.md` owns outcomes.
-- `plane` — an existing `plane:<identifier>` owns the outcome; integration is reference-only.
+- `plane` — an existing `plane:<identifier>` owns the outcome; integration is reference-only. Requires `project`.
+- `linear` — an existing `linear:<TEAM>-<n>` issue owns the outcome; integration is reference-only. Requires `team`, an uppercase Linear team key such as `CEW`, and accepts an optional `project`.
 - `none` — no persistent roadmap authority.
 
-`linear` is reserved but unsupported. Do not accept it as configuration until a real provider exists.
+A Linear roadmap:
+
+```json
+{
+  "version": 1,
+  "roadmap": { "provider": "linear", "team": "CEW", "project": "Example Product" },
+  "execution": { "provider": "kata", "project": "example-product" }
+}
+```
+
+Linear issue keys belong to the team, not the project: an issue keeps `CEW-123` in any project of team `CEW`. `project` records which Linear project this repository's outcomes belong to; it never appears in a reference.
 
 Supported execution providers:
 
@@ -102,12 +113,13 @@
 Specs use the roadmap provider's native header:
 
 - Plane: `**Outcome:** plane:PROJ-12`
+- Linear: `**Outcome:** linear:CEW-123`
 - File roadmap: `**Milestone:** M1 — Outcome title`
 - Bootstrap/no roadmap: `**Outcome:** none (bootstrap)`
 
 Plans carry one provider-neutral header copied or derived from the spec:
 
-- Plane: copy the outcome value as `**Source:** plane:PROJ-12`.
+- Plane or Linear: copy the outcome value unchanged, as `**Source:** plane:PROJ-12` or `**Source:** linear:CEW-123`.
 - File roadmap: convert `**Milestone:** M1 — Outcome title` to
   `**Source:** file:M1 — Outcome title`.
 - No roadmap: copy the value as `**Source:** none (bootstrap)`.
@@ -129,7 +141,7 @@
 
 The command repeats checked provider resolution before mutation, creates one containment parent plus one child per numbered plan task, and prints normalized refs. The parent is labeled `sjujperpowers-plan`; children are labeled `sjujperpowers-task`. Every child also blocks the parent, so the parent cannot become ready before all children close. Automatic selection MUST use `kata next --label sjujperpowers-task --json` and can never claim a plan root.
 
-Stable idempotency keys derive from the Kata project and repository-relative plan path, so retry the same command after a partial failure; do not create replacement issues manually. The parent and children record `sjujperpowers.plan`, `sjujperpowers.spec`, and `sjujperpowers.source` metadata. Children additionally record `sjujperpowers.task`. The source is provider-neutral, so `file + kata`, `plane + kata`, and bootstrap sources materialize identically.
+Stable idempotency keys derive from the Kata project and repository-relative plan path, so retry the same command after a partial failure; do not create replacement issues manually. The parent and children record `sjujperpowers.plan`, `sjujperpowers.spec`, and `sjujperpowers.source` metadata. Children additionally record `sjujperpowers.task`. The source is provider-neutral, so `file + kata`, `plane + kata`, `linear + kata`, and bootstrap sources materialize identically.
 
 Recover a named plan's mapping in a fresh session with:
 
@@ -148,6 +160,10 @@
 
 Use modules to group focused initiatives on Plane editions without Initiatives. Coordinate cross-project efforts with linked work items in each participating project rather than assuming a paid or unavailable Initiative feature.
 
+## Linear
+
+Linear support is reference-based, like Plane: lifecycle skills never create, update, or close Linear issues, and never call the Linear API or a Linear MCP tool. A human or a separately authorized integration applies curated roll-ups.
+
 ## Completion boundary
 
 Verification records evidence but does not close Kata work. Close only after the configured completion event succeeds:
````

- [ ] **Step 2: Update the lifecycle skills**

````diff
--- a/skills/roadmapping/SKILL.md
+++ b/skills/roadmapping/SKILL.md
@@ -7,7 +7,7 @@
 
 ## Overview
 
-Roadmapping orients work to the configured outcome authority. The default `file` provider uses `docs/project/roadmap.md`; `plane` carries an existing external outcome reference without editing a local roadmap; `none` intentionally skips persistent roadmap state. Milestones and external outcomes are results, not tickets. Hierarchy: roadmap source → spec → plan → task.
+Roadmapping orients work to the configured outcome authority. The default `file` provider uses `docs/project/roadmap.md`; `plane` and `linear` carry an existing external outcome reference without editing a local roadmap; `none` intentionally skips persistent roadmap state. Milestones and external outcomes are results, not tickets. Hierarchy: roadmap source → spec → plan → task.
 
 **Announce at start:** "I'm using the roadmapping skill to [create | revise | orient] the project roadmap."
 
@@ -65,6 +65,12 @@
 
 On Plane editions without Initiatives, use modules for focused initiatives and linked work items for cross-project efforts. Never assume the Initiatives feature exists.
 
+### Linear
+
+Require an existing provider-qualified outcome such as `linear:CEW-123`. Linear issue keys belong to the configured team, not a project: an issue keeps its `CEW-<n>` key in every project of team `CEW`. Linear support is reference-based: never claim to create, edit, or close the issue, and do not call the Linear API or a Linear MCP tool. Do not create or update `docs/project/roadmap.md`.
+
+Orient by reporting the supplied outcome reference, the configured Linear team and project (when set), known acceptance context, and the next spec. If the request needs a new or revised outcome, explain that it must be changed in Linear and stop until an existing reference is available.
+
 ### None
 
 Report that persistent roadmap state is intentionally disabled. Do not create a roadmap or manufacture a milestone. Hand off to brainstorming with `none (bootstrap)` or another explicit no-roadmap source.
--- a/skills/brainstorming/SKILL.md
+++ b/skills/brainstorming/SKILL.md
@@ -96,7 +96,7 @@
 For architectural work, use `docsRoot` from the checked provider configuration for every roadmap, spec, and plan path below. `docs/project` is only the default.
 
 **Architectural:**
-1. **Explore project context** — check files, docs, recent commits. Resolve the roadmap and execution providers first. For `file`, read `docs/project/roadmap.md` when present and state the milestone; if none fits, Revise first or proceed as `Milestone: none (unplanned)` with a Decisions line. For `plane`, require and state an existing `plane:<identifier>` outcome without editing the file roadmap. For `none`, state the explicit no-roadmap source. If the file provider has no roadmap AND the request is a new project, invoke roadmapping before continuing.
+1. **Explore project context** — check files, docs, recent commits. Resolve the roadmap and execution providers first. For `file`, read `docs/project/roadmap.md` when present and state the milestone; if none fits, Revise first or proceed as `Milestone: none (unplanned)` with a Decisions line. For `plane` or `linear`, require and state an existing `plane:<identifier>` or `linear:<TEAM>-<n>` outcome without editing the file roadmap. For `none`, state the explicit no-roadmap source. If the file provider has no roadmap AND the request is a new project, invoke roadmapping before continuing.
 2. **Ask clarifying questions** — one at a time, understand purpose/constraints/success criteria
 3. **Propose 2-3 approaches** — with trade-offs and your recommendation
 4. **Present design** — in sections scaled to their complexity, get user approval after each section
@@ -209,7 +209,7 @@
 - Write the validated design (spec) to `docs/project/specs/YYYY-MM-DD-<topic>-design.md`
   - (User preferences for spec location override this default)
   - For `file`, put `**Milestone:** M<N> — <title>` (or `**Milestone:** none (unplanned)`) immediately under the title.
-  - For `plane`, put the exact `**Outcome:** plane:<identifier>` immediately under the title.
+  - For `plane` or `linear`, put the exact `**Outcome:** plane:<identifier>` or `**Outcome:** linear:<TEAM>-<n>` immediately under the title.
   - For `none` or bootstrap work, put `**Outcome:** none (bootstrap)` and explain why.
 - Only the `file` provider may add the spec path to `docs/project/roadmap.md` and move a planned milestone to `active`.
 - Use elements-of-style:writing-clearly-and-concisely skill if available
--- a/skills/writing-plans/SKILL.md
+++ b/skills/writing-plans/SKILL.md
@@ -72,7 +72,7 @@
 **Spec:** [path to the spec/design doc this plan implements — the plan
 argues from the spec, so the spec travels with it; executors read both]
 
-**Source:** [copy or derive the approved spec's source: copy `plane:PROJ-12` or `none (bootstrap)`; convert `M1 — <title>` to `file:M1 — <title>`]
+**Source:** [copy or derive the approved spec's source: copy `plane:PROJ-12`, `linear:CEW-123`, or `none (bootstrap)`; convert `M1 — <title>` to `file:M1 — <title>`]
 
 ## Global Constraints
 
@@ -84,7 +84,7 @@
 ---
 ```
 
-For a file-roadmap spec, convert `**Milestone:** M1 — Title` to `**Source:** file:M1 — Title`. For Plane and bootstrap specs, copy the value from `**Outcome:**` unchanged. This source is independent of the execution provider.
+For a file-roadmap spec, convert `**Milestone:** M1 — Title` to `**Source:** file:M1 — Title`. For Plane, Linear, and bootstrap specs, copy the value from `**Outcome:**` unchanged. This source is independent of the execution provider.
 
 ## Task Structure
 
@@ -164,7 +164,7 @@
 jj commit docs/project/plans/YYYY-MM-DD-<feature-name>.md -m "Add <feature> implementation plan"
 ```
 
-If the plan serves a `file` roadmap milestone, include the roadmap edit (plan path under `**Plans:**`) in the same fileset: `jj commit docs/project/plans/<file>.md docs/project/roadmap.md -m …`. Never edit the file roadmap for `plane` or `none`.
+If the plan serves a `file` roadmap milestone, include the roadmap edit (plan path under `**Plans:**`) in the same fileset: `jj commit docs/project/plans/<file>.md docs/project/roadmap.md -m …`. Never edit the file roadmap for `plane`, `linear`, or `none`.
 
 If the resolved execution provider is `kata`, materialize only after the plan commit:
 
--- a/skills/finishing-a-change-stack/SKILL.md
+++ b/skills/finishing-a-change-stack/SKILL.md
@@ -46,7 +46,7 @@
 For the `file` provider, use `docsRoot` from the normalized configuration for the roadmap path. `docs/project` below is only the default.
 
 - `file`: if `docs/project/roadmap.md` is absent, skip. Otherwise ensure the plan path appears under its source milestone. If that milestone's `**Done when:**` is satisfied, set `**Status:** done` and ask one question whether the next planned milestone is still correct.
-- `plane`: do not edit the file roadmap or mutate Plane. Prepare a curated roll-up containing accepted scope, issue refs, verification, and the eventual completion result.
+- `plane` or `linear`: do not edit the file roadmap or mutate the external tracker. Prepare a curated roll-up containing accepted scope, issue refs, verification, and the eventual completion result.
 - `none`: skip roadmap mutation.
 
 Any file-roadmap edit lands in `@`; Step 3 describes it. A later confirmed discard abandons it with the rest of the stack.
@@ -179,7 +179,7 @@
 
 When a verdict exists, append the `verdict.mjs summary` output saved before the bookmark moved to the parent's close message (local land) so the durable record carries it. For pull-request completion the PR body already carries it. Keep-as-is, discard, and failed outcomes record nothing extra.
 
-For Plane, render one curated roll-up after the action and Kata finalization. Do not apply it or close the external outcome automatically.
+For Plane or Linear, render one curated roll-up after the action and Kata finalization. Do not apply it or close the external outcome automatically.
 
 ## Step 7: Workspace Cleanup
 
--- a/skills/using-sjujperpowers/SKILL.md
+++ b/skills/using-sjujperpowers/SKILL.md
@@ -33,7 +33,7 @@
 - "Let's build X" → sjujperpowers:brainstorming first, then implementation skills.
 - "Where are we / what's next" → sjujperpowers:roadmapping.
 - "Fix this bug" → sjujperpowers:systematic-debugging first, then domain skills.
-- "Use Plane/Kata tracking" → the lifecycle skill, then sjujperpowers:tracking-providers before mutation.
+- "Use Plane/Linear/Kata tracking" → the lifecycle skill, then sjujperpowers:tracking-providers before mutation.
 
 ## Red Flags
 
````

- [ ] **Step 3: Update the README and testing docs**

````diff
--- a/README.md
+++ b/README.md
@@ -94,7 +94,7 @@
 ## The workflow
 
 1. **tracking-providers** (`sjujperpowers:tracking-providers`) — Resolve repository-local provider policy and preflight selected execution services.
-2. **roadmapping** (`sjujperpowers:roadmapping`) — Capture an outcome in a file roadmap, reference an external Plane work item, or skip durable roadmap state.
+2. **roadmapping** (`sjujperpowers:roadmapping`) — Capture an outcome in a file roadmap, reference an external Plane work item or Linear issue, or skip durable roadmap state.
 3. **brainstorming** (`sjujperpowers:brainstorming`) — Refine the outcome into a versioned spec.
 4. **writing-plans** (`sjujperpowers:writing-plans`) — Break the spec into numbered tasks. A Kata-backed plan materializes a non-executable plan root plus one executable child per task.
 5. **starting-a-change** (`sjujperpowers:starting-a-change`) — Claim a configured Kata child, when applicable, then isolate work on a fresh change on `trunk()`.
@@ -156,7 +156,19 @@
 }
 ```
 
-Supported roadmap providers are `file`, `plane`, and `none`; execution providers are `session`, `kata`, and `none`. Kata is optional. When selected, its executable, daemon, and project must pass preflight before any issue or repository mutation.
+Supported roadmap providers are `file`, `plane`, `linear`, and `none`; execution providers are `session`, `kata`, and `none`. Kata is optional. When selected, its executable, daemon, and project must pass preflight before any issue or repository mutation.
+
+A Linear roadmap names a team key; references are that team's issue keys, such as `linear:CEW-123`, and `project` is optional:
+
+```json
+{
+  "version": 1,
+  "roadmap": { "provider": "linear", "team": "CEW", "project": "Example Product" },
+  "execution": { "provider": "kata", "project": "example-product" }
+}
+```
+
+Linear support is reference-only, like Plane.
 
 Use one Plane workspace as the portfolio boundary and projects as product or repository ownership boundaries. On Community Edition, use modules for focused initiatives and linked work items in each participating project for cross-project efforts. Plane owns outcomes and priorities; Sjujperpowers only renders curated roll-ups, never silent remote mutations.
 
--- a/docs/testing.md
+++ b/docs/testing.md
@@ -39,13 +39,16 @@
 ```bash
 node --test tests/tracking-providers/test-resolve-config.mjs
 node --test tests/tracking-providers/test-materialize-plan.mjs
+node --test tests/tracking-providers/test-roadmap-providers.mjs
 ```
 
-Run both behavioral fixtures:
+Run the behavioral fixtures:
 
 ```bash
 evals/run setup tracking-providers-plane
 evals/run post tracking-providers-plane <fixture-dir>
+evals/run setup tracking-providers-linear
+evals/run post tracking-providers-linear <fixture-dir>
 evals/run setup tracking-providers-kata
 evals/run post tracking-providers-kata <fixture-dir>
 evals/run setup tracking-providers-kata-landed
````

- [ ] **Step 4: Verify no stale claim remains**

Run: `grep -rn -E 'reserved but unsupported|file, plane, none|`file`, `plane`, and `none`' skills README.md docs/testing.md`
Expected: no output.

Run: `for f in tests/tracking-providers/*.mjs; do node --test "$f" || exit 1; done`
Expected: every file `# fail 0`.

- [ ] **Step 5: Commit**

```bash
jj commit skills/tracking-providers/SKILL.md skills/roadmapping/SKILL.md skills/brainstorming/SKILL.md skills/writing-plans/SKILL.md skills/finishing-a-change-stack/SKILL.md skills/using-sjujperpowers/SKILL.md README.md docs/testing.md -m "Document the Linear roadmap provider"
```

- [ ] **Step 6: Run the scenario with the updated skills (GREEN, controller)**

Repeat Task 2 Step 6 with a fresh copy of the stack's `skills/` directory, which now carries this task's text.
Expected: post passes all 7 checks; every acceptance criterion in `story.md` holds from the transcript (resolver run before writing, exact `linear:DEMO-12` in spec and plan, no roadmap file, no Linear writes or API/MCP calls, stops after planning). If it fails, record the agent's rationalization, tighten the skill text it ignored, and re-run.

## Final acceptance (controller, after Task 3)

1. Through the `linear` MCP server, create one scratch issue in team `CEW` whose description links SJUP-3. Read it back through the MCP server and note its key `CEW-<n>`.
2. In a temporary jj repository whose `.sjujperpowers/config.json` is `{"version":1,"roadmap":{"provider":"linear","team":"CEW"},"execution":{"provider":"kata","project":"sjujperpowers"}}`, run the checked resolver (`node <stack>/skills/tracking-providers/scripts/resolve-config.mjs --root <tmp>`, Kata preflight included) and confirm it prints the Linear roadmap.
3. Parse and materialize a two-task plan with `**Source:** linear:CEW-<n>` through `parsePlan` and `materializePlan` using a recording fake `runKata` (no real Kata issues), and confirm the parent and both children carry `sjujperpowers.source=linear:CEW-<n>`.
4. Record the issue key, the commands, and their results as a comment on SJUP-3. Leave the scratch issue in Linear; it is the only Linear write.
