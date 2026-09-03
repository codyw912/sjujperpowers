import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { dirname, resolve } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';
import test from 'node:test';

const __dirname = dirname(fileURLToPath(import.meta.url));
const repoRoot = resolve(__dirname, '../..');
const packageJsonPath = resolve(repoRoot, 'package.json');
const extensionPath = resolve(repoRoot, '.omp/extensions/sjujperpowers.ts');
const piToolsPath = resolve(repoRoot, 'skills/using-sjujperpowers/references/pi-tools.md');

async function loadExtension() {
  const handlers = new Map();
  const omp = {
    on(event, handler) {
      if (!handlers.has(event)) handlers.set(event, []);
      handlers.get(event).push(handler);
    },
  };
  const mod = await import(pathToFileURL(extensionPath).href + `?cachebust=${Date.now()}-${Math.random()}`);
  mod.default(omp);
  return handlers;
}

test('package declares a separate OMP extension', async () => {
  const pkg = JSON.parse(await readFile(packageJsonPath, 'utf8'));

  assert.deepEqual(pkg.omp, {
    extensions: ['./.omp/extensions/sjujperpowers.ts'],
  });
  assert.deepEqual(pkg.pi.extensions, ['./.pi/extensions/sjujperpowers.ts']);
});

test('OMP extension discovers skills without bootstrap hooks', async () => {
  const handlers = await loadExtension();

  assert.deepEqual([...handlers.keys()], ['resources_discover']);
  const [discover] = handlers.get('resources_discover');
  const result = await discover({ type: 'resources_discover', cwd: repoRoot, reason: 'startup' }, {});

  assert.deepEqual(result.skillPaths, [resolve(repoRoot, 'skills')]);
});

test('OMP guidance translates namespaced skill identifiers to bare URIs', async () => {
  const text = await readFile(piToolsPath, 'utf8');

  assert.match(text, /sjujperpowers:<name>.*skill:\/\/<name>/s);
  assert.match(text, /Do not include the\s+`sjujperpowers:` namespace in an OMP skill URI\./);
});
