import { test, after } from 'node:test';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const SCRIPT = path.join(
  path.dirname(fileURLToPath(import.meta.url)),
  '../../skills/verifying-by-risk/scripts/classify-risk.mjs',
);

process.env.JJ_USER = 'vbr-test';
process.env.JJ_EMAIL = 'vbr-test@example.com';

// Every temp dir this file creates, removed once the file's tests finish.
const tempDirs = [];
after(() => {
  for (const dir of tempDirs) fs.rmSync(dir, { recursive: true, force: true });
});

function tempDir(prefix = 'vbr-') {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), prefix));
  tempDirs.push(dir);
  return dir;
}

function jj(repo, args) {
  const result = spawnSync('jj', args, { cwd: repo, encoding: 'utf8' });
  if (result.status !== 0) {
    throw new Error(
      `jj ${args.join(' ')} failed (${result.status}): ${result.stderr || result.stdout}`,
    );
  }
  return result;
}

function rev(repo, revset, template) {
  return jj(repo, ['log', '-r', revset, '--no-graph', '-T', template]).stdout.trim();
}

function initRepo() {
  const dir = tempDir();
  jj(dir, ['git', 'init', '--quiet', dir]);
  fs.writeFileSync(path.join(dir, 'README'), 'base\n');
  jj(dir, ['describe', '-m', 'base']);
  jj(dir, ['bookmark', 'create', 'main', '-r', '@']);
  return dir;
}

function classify(repo, args = []) {
  const result = spawnSync(process.execPath, [SCRIPT, '--repo', repo, ...args], {
    encoding: 'utf8',
  });
  let json = null;
  try {
    json = JSON.parse(result.stdout);
  } catch {
    json = null;
  }
  return { status: result.status, stdout: result.stdout, stderr: result.stderr, json };
}

function writeRisk(repo, body) {
  const dir = path.join(repo, '.sjujperpowers');
  fs.mkdirSync(dir, { recursive: true });
  fs.writeFileSync(path.join(dir, 'risk.toml'), body);
}

test('multi-change stack: earlier protected path, range.from is fork point', () => {
  const repo = initRepo();
  const mainCommit = rev(repo, 'main', 'commit_id');
  jj(repo, ['new', '-m', 'touch hk']);
  fs.mkdirSync(path.join(repo, '.hk'), { recursive: true });
  fs.writeFileSync(path.join(repo, '.hk', 'x.pkl'), 'x\n');
  jj(repo, ['new', '-m', 'later']);
  fs.writeFileSync(path.join(repo, 'later.txt'), 'later\n');
  const head = rev(repo, '@', 'commit_id');
  const out = classify(repo);
  assert.equal(out.status, 0, out.stderr);
  assert.equal(out.json.protected, true);
  assert.equal(out.json.range.from, mainCommit);
  assert.equal(out.json.range.to, head);
  assert.ok(out.json.protectedPaths.includes('.hk/x.pkl'));
  const targets = out.json.paths.map((p) => p.to);
  assert.ok(targets.includes('.hk/x.pkl'));
  assert.ok(targets.includes('later.txt'));
});

test('--range starting at @- is rejected', () => {
  const repo = initRepo();
  jj(repo, ['new', '-m', 'c1']);
  fs.writeFileSync(path.join(repo, 'a.txt'), 'a\n');
  jj(repo, ['new', '-m', 'c2']);
  fs.writeFileSync(path.join(repo, 'b.txt'), 'b\n');
  const parent = rev(repo, '@-', 'commit_id');
  const head = rev(repo, '@', 'commit_id');
  const out = classify(repo, ['--range', `${parent}..${head}`]);
  assert.equal(out.status, 2, out.stderr + out.stdout);
  assert.match(out.stderr, /range/i);
  assert.match(out.stderr, /[0-9a-f]{12}/);
});

function git(dir, args) {
  const result = spawnSync(
    'git',
    ['-c', 'user.email=a@b.c', '-c', 'user.name=t', ...args],
    { cwd: dir, encoding: 'utf8' },
  );
  assert.equal(result.status, 0, `git ${args.join(' ')}: ${result.stderr}`);
  return result;
}

function originCommit(origin, file, message) {
  fs.writeFileSync(path.join(origin, file), `${message}\n`);
  git(origin, ['add', file]);
  git(origin, ['commit', '-q', '-m', message]);
}

// A jj clone of a git origin whose main is tracked. Returns both directories.
function cloneRepo() {
  const origin = tempDir('vbr-origin-');
  git(origin, ['init', '-q', '-b', 'main']);
  originCommit(origin, 'README', 'origin base');
  const repo = tempDir();
  jj(origin, ['git', 'clone', '--quiet', origin, repo]);
  return { origin, repo };
}

// Land one change on local main only (never pushed); returns its commit.
function landLocally(repo, file) {
  jj(repo, ['new', 'main', '-m', `landed ${file}`]);
  fs.writeFileSync(path.join(repo, file), 'landed\n');
  jj(repo, ['bookmark', 'set', 'main', '-r', '@']);
  return rev(repo, 'main', 'commit_id');
}

function startWork(repo, file) {
  jj(repo, ['new', '-m', 'feature']);
  fs.writeFileSync(path.join(repo, file), 'feature\n');
}

test('trunk is local main even when it is one landed change ahead of main@origin', () => {
  const { repo } = cloneRepo();
  const originMain = rev(repo, 'main@origin', 'commit_id');
  const landed = landLocally(repo, 'landed.txt');
  assert.notEqual(landed, originMain);
  startWork(repo, 'feature.txt');
  const out = classify(repo);
  assert.equal(out.status, 0, out.stderr);
  assert.equal(out.json.policy.bookmark, 'main');
  assert.equal(out.json.policy.commit, landed);
  assert.equal(out.json.range.from, landed);
  const sides = out.json.paths.flatMap((p) => [p.from, p.to]);
  assert.equal(sides.includes('landed.txt'), false);
  assert.deepEqual(sides.filter(Boolean), ['feature.txt', 'feature.txt']);
});

test('local main diverged from a tracked main@origin (conflicted bookmark) exits 2', () => {
  const { origin, repo } = cloneRepo();
  landLocally(repo, 'local.txt');
  startWork(repo, 'feature.txt');
  originCommit(origin, 'origin-only.txt', 'origin only');
  jj(repo, ['git', 'fetch']);
  assert.equal(rev(repo, 'bookmarks(exact:"main")', 'commit_id').length, 80, 'main should be conflicted');
  const out = classify(repo);
  assert.equal(out.status, 2, out.stdout);
  assert.match(out.stderr, /trunk: local main is conflicted/);
  assert.equal(out.json, null);
});

test('local main moved independently of an untracked, moved main@origin exits 2', () => {
  const { origin, repo } = cloneRepo();
  jj(repo, ['bookmark', 'untrack', 'main@origin']);
  landLocally(repo, 'local.txt');
  startWork(repo, 'feature.txt');
  originCommit(origin, 'origin-only.txt', 'origin only');
  jj(repo, ['git', 'fetch']);
  assert.equal(rev(repo, 'bookmarks(exact:"main")', 'commit_id').length, 40);
  const out = classify(repo);
  assert.equal(out.status, 2, out.stdout);
  assert.match(out.stderr, /trunk: local main and main@origin have diverged/);
});

test('local main behind main@origin exits 2', () => {
  const { origin, repo } = cloneRepo();
  const base = rev(repo, 'main', 'commit_id');
  originCommit(origin, 'origin-only.txt', 'origin only');
  jj(repo, ['git', 'fetch']);
  jj(repo, ['bookmark', 'set', 'main', '-r', base, '--allow-backwards']);
  startWork(repo, 'feature.txt');
  const out = classify(repo);
  assert.equal(out.status, 2, out.stdout);
  assert.match(out.stderr, /trunk: local main is behind main@origin/);
});

test('local main equal to main@origin classifies normally', () => {
  const { repo } = cloneRepo();
  const base = rev(repo, 'main', 'commit_id');
  startWork(repo, 'feature.txt');
  const out = classify(repo);
  assert.equal(out.status, 0, out.stderr);
  assert.equal(out.json.range.from, base);
});

test('main moved past fork point: trunk-only files are not in paths', () => {
  const repo = initRepo();
  jj(repo, ['new', '-m', 'feature']);
  fs.writeFileSync(path.join(repo, 'feature.txt'), 'feature\n');
  const featureChange = rev(repo, '@', 'change_id');
  const fork = rev(repo, 'main', 'commit_id');
  jj(repo, ['new', 'main', '-m', 'trunk only']);
  fs.writeFileSync(path.join(repo, 'trunk-only.txt'), 'trunk\n');
  jj(repo, ['bookmark', 'set', 'main', '-r', '@']);
  const out = classify(repo, ['--head', featureChange]);
  assert.equal(out.status, 0, out.stderr);
  assert.equal(out.json.range.from, fork);
  const sides = out.json.paths.flatMap((p) => [p.from, p.to]);
  assert.equal(sides.includes('trunk-only.txt'), false);
  assert.ok(sides.includes('feature.txt'));
});

test('change edits risk.toml to downgrade; policy still comes from main', () => {
  const repo = initRepo();
  writeRisk(repo, 'version = 1\ndefault = "high"\n[[rule]]\npaths = ["src/**"]\ntier = "high"\n');
  jj(repo, ['describe', '-m', 'base with policy']);
  jj(repo, ['new', '-m', 'downgrade']);
  writeRisk(repo, 'version = 1\ndefault = "low"\n[[rule]]\npaths = ["src/**"]\ntier = "low"\n');
  fs.mkdirSync(path.join(repo, 'src'), { recursive: true });
  fs.writeFileSync(path.join(repo, 'src', 'app.js'), 'x\n');
  const mainCommit = rev(repo, 'main', 'commit_id');
  const out = classify(repo);
  assert.equal(out.status, 0, out.stderr);
  assert.equal(out.json.policy.commit, mainCommit);
  assert.equal(out.json.policy.riskToml, true);
  assert.equal(out.json.tier, 'high');
  assert.equal(out.json.paths.find((p) => p.to === 'src/app.js').tier, 'high');
  assert.equal(out.json.protected, true);
  assert.ok(out.json.protectedPaths.includes('.sjujperpowers/risk.toml'));
});

test('missing risk.toml classifies every path high', () => {
  const repo = initRepo();
  jj(repo, ['new', '-m', 'work']);
  fs.writeFileSync(path.join(repo, 'notes.txt'), 'n\n');
  const out = classify(repo);
  assert.equal(out.status, 0, out.stderr);
  assert.equal(out.json.policy.riskToml, false);
  assert.equal(out.json.tier, 'high');
  assert.equal(out.json.paths.find((p) => p.to === 'notes.txt').tier, 'high');
  assert.equal(out.json.protected, false);
});

test('malformed risk.toml fails closed: high plus policy.error, exit 0', () => {
  const repo = initRepo();
  writeRisk(repo, 'version = 2\ndefault = "low"\n');
  jj(repo, ['describe', '-m', 'bad policy']);
  jj(repo, ['new', '-m', 'work']);
  fs.writeFileSync(path.join(repo, 'notes.txt'), 'n\n');
  const out = classify(repo);
  assert.equal(out.status, 0, out.stderr);
  assert.equal(out.json.tier, 'high');
  assert.equal(out.json.policy.riskToml, true);
  assert.equal(typeof out.json.policy.error, 'string');
  assert.ok(out.json.policy.error.length > 0);
});

test('empty @ uses @-', () => {
  const repo = initRepo();
  jj(repo, ['new', '-m', 'work']);
  fs.writeFileSync(path.join(repo, 'work.txt'), 'w\n');
  const parentCommit = rev(repo, '@', 'commit_id');
  const parentChange = rev(repo, '@', 'change_id');
  jj(repo, ['new']);
  assert.equal(rev(repo, '@', 'empty'), 'true');
  const out = classify(repo);
  assert.equal(out.status, 0, out.stderr);
  assert.equal(out.json.head.commit, parentCommit);
  assert.equal(out.json.head.change, parentChange);
  assert.equal(out.json.range.to, parentCommit);
  assert.ok(out.json.paths.some((p) => p.to === 'work.txt'));
});

test('rename counts both sides', () => {
  const repo = initRepo();
  writeRisk(
    repo,
    'version = 1\ndefault = "low"\n[[rule]]\npaths = ["secret/**"]\ntier = "high"\n[[rule]]\npaths = ["public/**"]\ntier = "low"\n',
  );
  fs.mkdirSync(path.join(repo, 'secret'), { recursive: true });
  fs.writeFileSync(path.join(repo, 'secret', 'token.txt'), 't\n');
  jj(repo, ['describe', '-m', 'base with secret']);
  jj(repo, ['new', '-m', 'rename']);
  fs.mkdirSync(path.join(repo, 'public'), { recursive: true });
  fs.renameSync(path.join(repo, 'secret', 'token.txt'), path.join(repo, 'public', 'token.txt'));
  const out = classify(repo);
  assert.equal(out.status, 0, out.stderr);
  const row = out.json.paths.find((p) => p.status === 'renamed');
  assert.ok(row, JSON.stringify(out.json.paths));
  assert.equal(row.from, 'secret/token.txt');
  assert.equal(row.to, 'public/token.txt');
  assert.equal(row.tier, 'high');
  assert.equal(out.json.tier, 'high');
});

test('deletes are listed', () => {
  const repo = initRepo();
  fs.writeFileSync(path.join(repo, 'doomed.txt'), 'gone\n');
  jj(repo, ['describe', '-m', 'base with doomed']);
  jj(repo, ['new', '-m', 'delete']);
  fs.rmSync(path.join(repo, 'doomed.txt'));
  const out = classify(repo);
  assert.equal(out.status, 0, out.stderr);
  const row = out.json.paths.find((p) => p.from === 'doomed.txt');
  assert.ok(row);
  assert.equal(row.status, 'removed');
});

test('paths with spaces and newlines round-trip', () => {
  const repo = initRepo();
  jj(repo, ['new', '-m', 'odd names']);
  fs.writeFileSync(path.join(repo, 'file with spaces.txt'), 's\n');
  fs.writeFileSync(path.join(repo, 'weird\nname.txt'), 'n\n');
  const out = classify(repo);
  assert.equal(out.status, 0, out.stderr);
  const targets = out.json.paths.map((p) => p.to);
  assert.ok(targets.includes('file with spaces.txt'));
  assert.ok(targets.includes('weird\nname.txt'));
});

test('--raise only raises', () => {
  const repo = initRepo();
  writeRisk(repo, 'version = 1\ndefault = "low"\n');
  jj(repo, ['describe', '-m', 'policy']);
  jj(repo, ['new', '-m', 'work']);
  fs.writeFileSync(path.join(repo, 'notes.txt'), 'n\n');
  const raised = classify(repo, ['--raise', 'medium']);
  assert.equal(raised.status, 0, raised.stderr);
  assert.equal(raised.json.computedTier, 'low');
  assert.equal(raised.json.tier, 'medium');
  const lowered = classify(repo, ['--raise', 'low']);
  assert.equal(lowered.status, 0, lowered.stderr);
  assert.equal(lowered.json.computedTier, 'low');
  assert.equal(lowered.json.tier, 'low');
});

test('first matching rule wins', () => {
  const repo = initRepo();
  writeRisk(
    repo,
    'version = 1\ndefault = "low"\n[[rule]]\npaths = ["src/**"]\ntier = "medium"\n[[rule]]\npaths = ["src/special.js"]\ntier = "high"\n',
  );
  jj(repo, ['describe', '-m', 'policy']);
  jj(repo, ['new', '-m', 'work']);
  fs.mkdirSync(path.join(repo, 'src'), { recursive: true });
  fs.writeFileSync(path.join(repo, 'src', 'special.js'), 's\n');
  fs.writeFileSync(path.join(repo, 'other.txt'), 'o\n');
  const out = classify(repo);
  assert.equal(out.status, 0, out.stderr);
  assert.equal(out.json.paths.find((p) => p.to === 'src/special.js').tier, 'medium');
  assert.equal(out.json.paths.find((p) => p.to === 'other.txt').tier, 'low');
  assert.equal(out.json.tier, 'medium');
});

test('nothing pending exits 2', () => {
  const repo = initRepo();
  jj(repo, ['new']);
  const out = classify(repo);
  assert.equal(out.status, 2);
  assert.match(out.stderr, /nothing pending/);
});

test('missing main bookmark exits 2', () => {
  const repo = initRepo();
  jj(repo, ['bookmark', 'delete', 'main']);
  jj(repo, ['new', '-m', 'work']);
  fs.writeFileSync(path.join(repo, 'a.txt'), 'a\n');
  const out = classify(repo);
  assert.equal(out.status, 2);
  assert.match(out.stderr, /no trunk/);
});

test('matching --range is accepted', () => {
  const repo = initRepo();
  const mainCommit = rev(repo, 'main', 'commit_id');
  jj(repo, ['new', '-m', 'work']);
  fs.writeFileSync(path.join(repo, 'a.txt'), 'a\n');
  const head = rev(repo, '@', 'commit_id');
  const out = classify(repo, ['--range', `${mainCommit}..${head}`]);
  assert.equal(out.status, 0, out.stderr);
  assert.equal(out.json.range.from, mainCommit);
  assert.equal(out.json.range.to, head);
});

test('protected globs from risk.toml are honored', () => {
  const repo = initRepo();
  writeRisk(repo, 'version = 1\ndefault = "low"\nprotected = ["secrets/**"]\n');
  jj(repo, ['describe', '-m', 'policy']);
  jj(repo, ['new', '-m', 'work']);
  fs.mkdirSync(path.join(repo, 'secrets'), { recursive: true });
  fs.writeFileSync(path.join(repo, 'secrets', 'key.txt'), 'k\n');
  const out = classify(repo);
  assert.equal(out.status, 0, out.stderr);
  assert.equal(out.json.protected, true);
  assert.ok(out.json.protectedPaths.includes('secrets/key.txt'));
  assert.equal(out.json.paths.find((p) => p.to === 'secrets/key.txt').protected, true);
  assert.equal(out.json.tier, 'low');
});

test('built-in protected paths are reported by classification', () => {
  const repo = initRepo();
  writeRisk(repo, 'version = 1\ndefault = "low"\n');
  jj(repo, ['describe', '-m', 'policy']);
  jj(repo, ['new', '-m', 'work']);
  const files = [
    'devenv.nix',
    '.agents/skills/verify-x/SKILL.md',
    '.agents/skills/verify-x/features/a.md',
  ];
  for (const file of files) {
    fs.mkdirSync(path.dirname(path.join(repo, file)), { recursive: true });
    fs.writeFileSync(path.join(repo, file), 'x\n');
  }
  fs.writeFileSync(path.join(repo, 'plain.txt'), 'p\n');
  const out = classify(repo);
  assert.equal(out.status, 0, out.stderr);
  assert.equal(out.json.protected, true);
  assert.deepEqual(out.json.protectedPaths, [...files].sort());
  assert.equal(out.json.paths.find((p) => p.to === 'plain.txt').protected, false);
  assert.equal(out.json.tier, 'low');
});

test('testCommand comes from risk.toml on trunk; absent is null', () => {
  const repo = initRepo();
  writeRisk(repo, 'version = 1\ndefault = "low"\n');
  jj(repo, ['describe', '-m', 'policy']);
  jj(repo, ['new', '-m', 'work']);
  fs.writeFileSync(path.join(repo, 'a.txt'), 'a\n');
  assert.equal(classify(repo).json.testCommand, null);

  const withTest = initRepo();
  writeRisk(withTest, 'version = 1\ndefault = "low"\ntest = "node --test tests/"\n');
  jj(withTest, ['describe', '-m', 'policy']);
  jj(withTest, ['new', '-m', 'work']);
  fs.writeFileSync(path.join(withTest, 'a.txt'), 'a\n');
  const out = classify(withTest);
  assert.equal(out.status, 0, out.stderr);
  assert.equal(out.json.testCommand, 'node --test tests/');
  assert.equal(out.json.policy.bookmark, 'main');
});

test('a stack that edits the test command still reports the one on trunk', () => {
  const repo = initRepo();
  writeRisk(repo, 'version = 1\ndefault = "low"\ntest = "node --test tests/"\n');
  jj(repo, ['describe', '-m', 'policy']);
  jj(repo, ['new', '-m', 'swap test']);
  writeRisk(repo, 'version = 1\ndefault = "low"\ntest = "true"\n');
  const out = classify(repo);
  assert.equal(out.status, 0, out.stderr);
  assert.equal(out.json.testCommand, 'node --test tests/');
  assert.equal(out.json.protected, true);
  assert.ok(out.json.protectedPaths.includes('.sjujperpowers/risk.toml'));
});

test('invalid test command in risk.toml fails closed with no testCommand', () => {
  const repo = initRepo();
  writeRisk(repo, 'version = 1\ndefault = "low"\ntest = ""\n');
  jj(repo, ['describe', '-m', 'bad policy']);
  jj(repo, ['new', '-m', 'work']);
  fs.writeFileSync(path.join(repo, 'a.txt'), 'a\n');
  const out = classify(repo);
  assert.equal(out.status, 0, out.stderr);
  assert.equal(out.json.tier, 'high');
  assert.equal(out.json.testCommand, null);
  assert.match(out.json.policy.error, /test/);
});

test('verifySkill is true when a verify skill is on trunk or at head, false otherwise', () => {
  const skill = '.agents/skills/verify-demo/SKILL.md';
  const put = (repo, file) => {
    fs.mkdirSync(path.dirname(path.join(repo, file)), { recursive: true });
    fs.writeFileSync(path.join(repo, file), 'x\n');
  };

  const none = initRepo();
  jj(none, ['new', '-m', 'work']);
  put(none, 'a.txt');
  put(none, '.agents/skills/other/SKILL.md');
  put(none, '.agents/skills/verify-demo/notes.md');
  assert.equal(classify(none).json.verifySkill, false);

  const onTrunk = initRepo();
  put(onTrunk, skill);
  jj(onTrunk, ['describe', '-m', 'skill']);
  jj(onTrunk, ['new', '-m', 'work']);
  put(onTrunk, 'a.txt');
  assert.equal(classify(onTrunk).json.verifySkill, true);

  const atHead = initRepo();
  jj(atHead, ['new', '-m', 'work']);
  put(atHead, skill);
  assert.equal(classify(atHead).json.verifySkill, true);

  // Deleting trunk's skill in the stack still counts: trunk has it.
  const deleted = initRepo();
  put(deleted, skill);
  jj(deleted, ['describe', '-m', 'skill']);
  jj(deleted, ['new', '-m', 'drop skill']);
  fs.rmSync(path.join(deleted, skill));
  assert.equal(classify(deleted).json.verifySkill, true);
});
