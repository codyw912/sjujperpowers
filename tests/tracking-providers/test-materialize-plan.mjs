import assert from 'node:assert/strict';
import test from 'node:test';

import {
  materializePlan,
  parsePlan,
} from '../../skills/tracking-providers/scripts/materialize-plan.mjs';

const plan = `# Provider Example Implementation Plan

**Spec:** \`docs/project/specs/example.md\`

**Source:** plane:SJUP-12

### Task 1: Resolver

Details.

### Task 2: Skill integration

Details.
`;

function kataConfig(roadmap = { provider: 'plane', project: 'Example' }) {
  return {
    version: 1,
    configPath: '/repo/.sjujperpowers/config.json',
    roadmap,
    execution: {
      provider: 'kata',
      project: 'sjujperpowers',
      completion: 'landed',
    },
  };
}

function fakeKata(calls, overrides = {}) {
  return async (args) => {
    calls.push(args);
    if (overrides.failAt === calls.length) throw new Error('simulated create failure');
    const key = args[args.indexOf('--idempotency-key') + 1];
    const shortId = key.endsWith(':parent') ? 'root' : `t${calls.length - 1}`;
    return { issue: { short_id: shortId }, ...overrides.response };
  };
}

test('parsePlan extracts a provider-neutral source and stable tasks', () => {
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

test('parsePlan ignores task-shaped headings inside fenced code', () => {
  const withFence = plan.replace(
    'Details.\n\n### Task 2',
    'Details.\n\n```markdown\n### Task 99: Example only\n```\n\n### Task 2',
  );
  assert.deepEqual(
    parsePlan(withFence).tasks,
    [
      { number: 1, title: 'Resolver' },
      { number: 2, title: 'Skill integration' },
    ],
  );
});

test('materialization creates one parent and one child per task', async () => {
  const calls = [];
  const result = await materializePlan({
    root: '/repo',
    planPath: '/repo/docs/project/plans/example.md',
    markdown: plan,
    config: kataConfig(),
    runKata: fakeKata(calls),
  });

  assert.equal(calls.length, 3);
  assert.deepEqual(calls[0].slice(0, 4), [
    '--project',
    'sjujperpowers',
    '--json',
    'create',
  ]);
  assert.match(calls[0].join(' '), /sjujperpowers\.source=plane:SJUP-12/);
  assert.equal(calls[0][calls[0].indexOf('--label') + 1], 'sjujperpowers-plan');
  assert.equal(calls[1][calls[1].indexOf('--label') + 1], 'sjujperpowers-task');
  assert.equal(calls[1][calls[1].indexOf('--parent') + 1], 'root');
  assert.equal(calls[1][calls[1].indexOf('--blocks') + 1], 'root');
  assert.deepEqual(result, {
    parent: { ref: 'sjujperpowers#root', created: true },
    children: [
      { task: 1, ref: 'sjujperpowers#t1', created: true },
      { task: 2, ref: 'sjujperpowers#t2', created: true },
    ],
  });
});

test('file roadmap source materializes through Kata without Plane', async () => {
  const calls = [];
  const filePlan = plan.replace('plane:SJUP-12', 'file:M1 — Provider framework');

  await materializePlan({
    root: '/repo',
    planPath: '/repo/docs/project/plans/file-backed.md',
    markdown: filePlan,
    config: kataConfig({ provider: 'file' }),
    runKata: fakeKata(calls),
  });

  assert.equal(calls.length, 3);
  assert.match(
    calls[0].join(' '),
    /sjujperpowers\.source=file:M1 — Provider framework/,
  );
  assert.doesNotMatch(calls.flat().join(' '), /plane:/);
});

test('idempotent replay is normalized as not created', async () => {
  const calls = [];
  const result = await materializePlan({
    root: '/repo',
    planPath: '/repo/docs/project/plans/example.md',
    markdown: plan,
    config: kataConfig(),
    runKata: fakeKata(calls, { response: { reused: true, changed: false } }),
  });

  assert.equal(result.parent.created, false);
  assert.ok(result.children.every((child) => child.created === false));
});

for (const [name, markdown, message] of [
  ['missing title', plan.replace('# Provider Example Implementation Plan', '# Provider Example'), 'implementation-plan title'],
  ['missing spec', plan.replace('**Spec:** `docs/project/specs/example.md`\n\n', ''), 'Spec header'],
  ['missing source', plan.replace('**Source:** plane:SJUP-12\n\n', ''), 'Source header'],
  ['missing tasks', plan.replace(/^### Task[\s\S]*$/m, ''), 'at least one Task heading'],
  ['duplicate tasks', plan.replace('### Task 2:', '### Task 1:'), 'task numbers must be exactly 1, 2, ...'],
  ['skipped tasks', plan.replace('### Task 2:', '### Task 3:'), 'task numbers must be exactly 1, 2, ...'],
]) {
  test(`${name} fails before issue creation`, async () => {
    let called = false;
    await assert.rejects(
      materializePlan({
        root: '/repo',
        planPath: '/repo/plan.md',
        markdown,
        config: kataConfig(),
        runKata: async () => {
          called = true;
        },
      }),
      new RegExp(message),
    );
    assert.equal(called, false);
  });
}

test('non-Kata execution provider fails before issue creation', async () => {
  let called = false;
  await assert.rejects(
    materializePlan({
      root: '/repo',
      planPath: '/repo/plan.md',
      markdown: plan,
      config: {
        ...kataConfig(),
        execution: { provider: 'session', completion: 'landed' },
      },
      runKata: async () => {
        called = true;
      },
    }),
    /execution\.provider must be kata/,
  );
  assert.equal(called, false);
});

test('plan outside repository fails before issue creation', async () => {
  let called = false;
  await assert.rejects(
    materializePlan({
      root: '/repo',
      planPath: '/other/plan.md',
      markdown: plan,
      config: kataConfig(),
      runKata: async () => {
        called = true;
      },
    }),
    /plan must be inside repository root/,
  );
  assert.equal(called, false);
});

test('raw Kata output must contain issue.short_id', async () => {
  await assert.rejects(
    materializePlan({
      root: '/repo',
      planPath: '/repo/plan.md',
      markdown: plan,
      config: kataConfig(),
      runKata: async () => ({ changed: true }),
    }),
    /Kata create response is missing issue\.short_id/,
  );
});

test('partial failure reports already created references for safe retry', async () => {
  const calls = [];
  await assert.rejects(
    materializePlan({
      root: '/repo',
      planPath: '/repo/plan.md',
      markdown: plan,
      config: kataConfig(),
      runKata: fakeKata(calls, { failAt: 3 }),
    }),
    (error) => {
      assert.match(error.message, /Task 2/);
      assert.deepEqual(error.partial, {
        parent: { ref: 'sjujperpowers#root', created: true },
        children: [{ task: 1, ref: 'sjujperpowers#t1', created: true }],
      });
      return true;
    },
  );
});
