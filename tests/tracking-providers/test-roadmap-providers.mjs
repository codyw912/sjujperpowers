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
