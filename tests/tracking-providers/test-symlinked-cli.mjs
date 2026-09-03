import assert from 'node:assert/strict';
import { execFile as execFileCallback } from 'node:child_process';
import { mkdtemp, mkdir, symlink } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { promisify } from 'node:util';
import test from 'node:test';

const execFile = promisify(execFileCallback);
const skillDir = dirname(fileURLToPath(new URL('../../skills/tracking-providers/SKILL.md', import.meta.url)));

async function symlinkedScript(name) {
  const root = await mkdtemp(join(tmpdir(), 'sjujperpowers-symlinked-cli-'));
  const skillsDir = join(root, 'skills');
  await mkdir(skillsDir);
  await symlink(skillDir, join(skillsDir, 'tracking-providers'), 'dir');
  return join(skillsDir, 'tracking-providers', 'scripts', name);
}

test('resolve-config CLI runs through a symlinked skill directory', async () => {
  const script = await symlinkedScript('resolve-config.mjs');
  const root = await mkdtemp(join(tmpdir(), 'sjujperpowers-default-config-'));
  const { stdout } = await execFile(process.execPath, [script, '--root', root]);

  assert.deepEqual(JSON.parse(stdout), {
    version: 1,
    configPath: null,
    roadmap: { provider: 'file' },
    execution: { provider: 'session', completion: 'landed' },
  });
});

test('materialize-plan CLI validates arguments through a symlinked skill directory', async () => {
  const script = await symlinkedScript('materialize-plan.mjs');

  await assert.rejects(
    execFile(process.execPath, [script, '--unknown']),
    (error) => error.code === 2 && /unknown argument: --unknown/.test(error.stderr),
  );
});
