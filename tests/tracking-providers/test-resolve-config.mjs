import assert from 'node:assert/strict';
import { mkdtemp, mkdir, writeFile } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import test from 'node:test';

import {
  normalizeConfig,
  preflightKata,
  resolveConfig,
} from '../../skills/tracking-providers/scripts/resolve-config.mjs';

async function fixture(config) {
  const root = await mkdtemp(join(tmpdir(), 'sjujperpowers-config-'));
  if (config !== undefined) {
    await mkdir(join(root, '.sjujperpowers'));
    await writeFile(
      join(root, '.sjujperpowers/config.json'),
      typeof config === 'string' ? config : JSON.stringify(config),
    );
  }
  return root;
}

const kataConfig = {
  version: 1,
  roadmap: { provider: 'plane', project: 'Sjujperpowers' },
  execution: {
    provider: 'kata',
    project: 'sjujperpowers',
    completion: 'pull_request',
  },
};

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
  assert.deepEqual(
    normalizeConfig(kataConfig, '/repo/.sjujperpowers/config.json'),
    {
      version: 1,
      configPath: '/repo/.sjujperpowers/config.json',
      roadmap: { provider: 'plane', project: 'Sjujperpowers' },
      execution: {
        provider: 'kata',
        project: 'sjujperpowers',
        completion: 'pull_request',
      },
    },
  );
});

test('roadmap and execution slots remain independent', () => {
  assert.deepEqual(
    normalizeConfig(
      {
        version: 1,
        roadmap: { provider: 'file' },
        execution: { provider: 'kata', project: 'repo' },
      },
      '/repo/.sjujperpowers/config.json',
    ),
    {
      version: 1,
      configPath: '/repo/.sjujperpowers/config.json',
      roadmap: { provider: 'file' },
      execution: { provider: 'kata', project: 'repo', completion: 'landed' },
    },
  );
});

test('omitted provider objects receive defaults', () => {
  assert.deepEqual(normalizeConfig({ version: 1 }, '/repo/config.json'), {
    version: 1,
    configPath: '/repo/config.json',
    roadmap: { provider: 'file' },
    execution: { provider: 'session', completion: 'landed' },
  });
});

test('malformed JSON names its file', async () => {
  const root = await fixture('{ nope');
  await assert.rejects(
    resolveConfig(root, { runtimeCheck: false }),
    new RegExp(`${root}/\\.sjujperpowers/config\\.json: invalid JSON`),
  );
});

for (const [name, config, field] of [
  ['unknown version', { version: 2 }, 'version'],
  ['unknown root key', { version: 1, typo: true }, 'root.typo'],
  ['unknown roadmap provider', { version: 1, roadmap: { provider: 'jira' } }, 'roadmap.provider'],
  ['reserved linear provider', { version: 1, roadmap: { provider: 'linear', project: 'x' } }, 'roadmap.provider'],
  ['missing Plane project', { version: 1, roadmap: { provider: 'plane' } }, 'roadmap.project'],
  ['wrong Plane project type', { version: 1, roadmap: { provider: 'plane', project: 3 } }, 'roadmap.project'],
  ['project on file provider', { version: 1, roadmap: { provider: 'file', project: 'x' } }, 'roadmap.project'],
  ['unknown execution provider', { version: 1, execution: { provider: 'github' } }, 'execution.provider'],
  ['missing Kata project', { version: 1, execution: { provider: 'kata' } }, 'execution.project'],
  ['project on session provider', { version: 1, execution: { provider: 'session', project: 'x' } }, 'execution.project'],
  ['invalid completion', { version: 1, execution: { provider: 'session', completion: 'verified' } }, 'execution.completion'],
  ['unknown execution key', { version: 1, execution: { provider: 'none', typo: true } }, 'execution.typo'],
]) {
  test(`${name} fails closed`, () => {
    assert.throws(
      () => normalizeConfig(config, '/repo/config.json'),
      new RegExp(`/repo/config\\.json: ${field.replace('.', '\\.')} `),
    );
  });
}

test('Kata preflight checks health before the configured project', async () => {
  const calls = [];

  await preflightKata('sjujperpowers', {
    commandExists: () => true,
    runCommand: async (command, args) => calls.push([command, ...args]),
    configPath: '/repo/config.json',
  });

  assert.deepEqual(calls, [
    ['kata', 'health', '--json'],
    ['kata', 'projects', 'show', 'sjujperpowers', '--json'],
  ]);
});

test('missing Kata executable fails before commands run', async () => {
  let ran = false;

  await assert.rejects(
    preflightKata('repo', {
      commandExists: () => false,
      runCommand: async () => {
        ran = true;
      },
      configPath: '/repo/config.json',
    }),
    /execution\.provider selects kata but the kata executable is unavailable/,
  );
  assert.equal(ran, false);
});

test('unreachable Kata daemon fails before project lookup', async () => {
  const calls = [];

  await assert.rejects(
    preflightKata('repo', {
      commandExists: () => true,
      runCommand: async (command, args) => {
        calls.push([command, ...args]);
        throw new Error('connection refused');
      },
      configPath: '/repo/config.json',
    }),
    /cannot reach the kata daemon: connection refused/,
  );
  assert.deepEqual(calls, [['kata', 'health', '--json']]);
});

test('unknown Kata project fails after health succeeds', async () => {
  const calls = [];

  await assert.rejects(
    preflightKata('missing', {
      commandExists: () => true,
      runCommand: async (command, args) => {
        calls.push([command, ...args]);
        if (args[0] === 'projects') throw new Error('project not found');
      },
      configPath: '/repo/config.json',
    }),
    /execution\.project kata project "missing" is unavailable: project not found/,
  );
  assert.equal(calls.length, 2);
});

test('resolveConfig performs checked Kata preflight by default', async () => {
  const root = await fixture(kataConfig);
  const calls = [];

  const config = await resolveConfig(root, {
    commandExists: () => true,
    runCommand: async (command, args) => calls.push([command, ...args]),
  });

  assert.equal(config.execution.project, 'sjujperpowers');
  assert.equal(calls.length, 2);
});

test('non-Kata configurations never contact Kata', async () => {
  const root = await fixture({
    version: 1,
    roadmap: { provider: 'plane', project: 'Example' },
    execution: { provider: 'session' },
  });

  await resolveConfig(root, {
    commandExists: () => {
      throw new Error('must not probe executables');
    },
    runCommand: async () => {
      throw new Error('must not run commands');
    },
  });
});
