import { test, after } from 'node:test';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

process.env.JJ_USER = 'vbr-test';
process.env.JJ_EMAIL = 'vbr-test@example.com';

const VERDICT = path.join(
  path.dirname(fileURLToPath(import.meta.url)),
  '../../skills/verifying-by-risk/scripts/verdict.mjs',
);
const TEST_COMMAND = 'node --test tests/';
const VERIFY_SKILL = '.agents/skills/verify-demo/SKILL.md';

// Every temp dir this file creates, removed once the file's tests finish.
const tempDirs = [];
after(() => {
  for (const dir of tempDirs) fs.rmSync(dir, { recursive: true, force: true });
});

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

function write(repo, file, body = 'x\n') {
  const full = path.join(repo, file);
  fs.mkdirSync(path.dirname(full), { recursive: true });
  fs.writeFileSync(full, body);
}

// A repo whose main has no risk.toml (every path classifies high). `verify` adds a
// verify skill to main.
function initRepo({ risk, verify = false } = {}) {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'vbr-'));
  tempDirs.push(dir);
  jj(dir, ['git', 'init', '--quiet', dir]);
  write(dir, 'README', 'base\n');
  if (risk !== undefined) write(dir, '.sjujperpowers/risk.toml', risk);
  if (verify) write(dir, VERIFY_SKILL);
  jj(dir, ['describe', '-m', 'base']);
  jj(dir, ['bookmark', 'create', 'main', '-r', '@']);
  return dir;
}

function policy({ tier = 'low', test = TEST_COMMAND } = {}) {
  return `version = 1\ndefault = "${tier}"\n${test ? `test = "${test}"\n` : ''}`;
}

// main declares a policy; a child change adds a.txt.
function workRepo({ verify, ...options } = {}) {
  const repo = initRepo({ risk: policy(options), verify });
  jj(repo, ['new', '-m', 'work']);
  write(repo, 'a.txt', 'a\n');
  return repo;
}

function run(repo, args) {
  return spawnSync(process.execPath, [VERDICT, '--repo', repo, ...args], { encoding: 'utf8' });
}

const receipt = (command = TEST_COMMAND, exit = 0) =>
  JSON.stringify({ command, exit, evidence: 'ok' });

function append(
  repo,
  { grade = 'blocked', implementer = 'grok', verifier, runs = [], extra = [] } = {},
) {
  const args = ['append', '--grade', grade, '--implementer-family', implementer];
  if (verifier) args.push('--verifier-family', verifier);
  for (const item of runs) args.push('--run', item);
  return run(repo, [...args, ...extra]);
}

const ledgerPath = (repo) => path.join(repo, '.sjujperpowers', 'verdicts.jsonl');

function readRows(repo) {
  return fs
    .readFileSync(ledgerPath(repo), 'utf8')
    .split('\n')
    .filter(Boolean)
    .map((line) => JSON.parse(line));
}

function tamperLastRow(repo, edit) {
  const rows = readRows(repo);
  edit(rows[rows.length - 1]);
  fs.writeFileSync(ledgerPath(repo), `${rows.map((row) => JSON.stringify(row)).join('\n')}\n`);
}

function check(repo, args = []) {
  const result = run(repo, ['check', ...args]);
  return { status: result.status, json: JSON.parse(result.stdout), stderr: result.stderr };
}

test('append no longer accepts --classification', () => {
  const repo = workRepo();
  const result = append(repo, { extra: ['--classification', '/tmp/does-not-matter.json'] });
  assert.equal(result.status, 2, result.stdout);
  assert.match(result.stderr, /--classification/);
  assert.equal(fs.existsSync(ledgerPath(repo)), false);
});

test('high tier with a verify skill needs a different-family verifier unless failed or blocked', () => {
  const repo = workRepo({ tier: 'high', verify: true });
  const same = append(repo, {
    grade: 'unit-tested',
    verifier: 'grok',
    runs: [receipt()],
  });
  assert.equal(same.status, 2, same.stderr);
  assert.match(same.stderr, /different-family/);
  const none = append(repo, { grade: 'live-verified', runs: [receipt()] });
  assert.equal(none.status, 2);
  assert.match(none.stderr, /different-family/);
  assert.equal(fs.existsSync(ledgerPath(repo)), false);
  assert.equal(append(repo, { grade: 'blocked' }).status, 0);
  assert.equal(append(repo, { grade: 'failed' }).status, 0);
  const different = append(repo, { grade: 'unit-tested', verifier: 'claude', runs: [receipt()] });
  assert.equal(different.status, 0, different.stderr);
});

test('a repo with no risk.toml classifies high, so append needs a different family once it has a verify skill', () => {
  const repo = initRepo({ verify: true });
  jj(repo, ['new', '-m', 'work']);
  write(repo, 'a.txt', 'a\n');
  // A graded row still needs a different-family verifier; the refusal lands
  // before the testCommand rule.
  const result = append(repo, { grade: 'unit-tested' });
  assert.equal(result.status, 2);
  assert.match(result.stderr, /different-family/);
  // With the verifier satisfied, a missing `test` declaration is a setup gap:
  // type-check-only is the ceiling, not a refusal.
  assert.match(
    append(repo, { grade: 'unit-tested', verifier: 'claude' }).stderr,
    /no test command; grade stops at type-check-only/,
  );
  assert.equal(append(repo, { grade: 'type-check-only', verifier: 'claude' }).status, 0);
});

test('no verify skill: high tier reaches unit-tested without a verifier but not behavior-tested', () => {
  const repo = workRepo({ tier: 'high' });
  const noReceipt = append(repo, { grade: 'unit-tested' });
  assert.equal(noReceipt.status, 2, noReceipt.stdout);
  assert.match(noReceipt.stderr, new RegExp(TEST_COMMAND));
  for (const grade of ['behavior-tested', 'live-verified']) {
    const refused = append(repo, { grade, verifier: 'claude', runs: [receipt()] });
    assert.equal(refused.status, 2, `${grade}: ${refused.stdout}`);
    assert.match(refused.stderr, /no verify skill: grade stops at unit-tested/);
  }
  assert.equal(fs.existsSync(ledgerPath(repo)), false);

  const earned = append(repo, { grade: 'unit-tested', runs: [receipt()] });
  assert.equal(earned.status, 0, earned.stderr);
  const [row] = readRows(repo);
  assert.equal(row.tier, 'high');
  assert.equal(row.verifySkill, false);
  assert.equal(row.verifierFamily, null);
});

test('behavior-tested is refused without a verify skill at low tier too', () => {
  const repo = workRepo();
  const refused = append(repo, { grade: 'behavior-tested', runs: [receipt()] });
  assert.equal(refused.status, 2, refused.stdout);
  assert.match(refused.stderr, /no verify skill: grade stops at unit-tested/);
});

test('a verify skill on trunk only, or at head only, requires a verifier at high tier', () => {
  const onTrunk = workRepo({ tier: 'high', verify: true });
  const head = workRepo({ tier: 'high' });
  write(head, VERIFY_SKILL);
  for (const [label, repo] of [['trunk only', onTrunk], ['head only', head]]) {
    const refused = append(repo, { grade: 'unit-tested', runs: [receipt()] });
    assert.equal(refused.status, 2, `${label}: ${refused.stdout}`);
    assert.match(refused.stderr, /different-family/, label);
    const ok = append(repo, { grade: 'unit-tested', verifier: 'claude', runs: [receipt()] });
    assert.equal(ok.status, 0, `${label}: ${ok.stderr}`);
    assert.equal(readRows(repo)[0].verifySkill, true, label);
  }
});

test('a stack that deletes trunk\'s verify skill is still held to the verifier rule', () => {
  const repo = workRepo({ tier: 'high', verify: true });
  fs.rmSync(path.join(repo, VERIFY_SKILL));
  const refused = append(repo, { grade: 'unit-tested', runs: [receipt()] });
  assert.equal(refused.status, 2, refused.stdout);
  assert.match(refused.stderr, /different-family/);
});

test('--code-reviewer is recorded, defaults to empty, and never satisfies the verifier', () => {
  const repo = workRepo({ tier: 'high', verify: true });
  const reviewed = append(repo, {
    grade: 'unit-tested',
    runs: [receipt()],
    extra: ['--code-reviewer', 'claude', '--code-reviewer', 'gemini'],
  });
  assert.equal(reviewed.status, 2, reviewed.stdout);
  assert.match(reviewed.stderr, /different-family/);
  assert.equal(fs.existsSync(ledgerPath(repo)), false);

  const blocked = append(repo, { grade: 'blocked', extra: ['--code-reviewer', 'claude', '--code-reviewer', 'gemini'] });
  assert.equal(blocked.status, 0, blocked.stderr);
  const bare = append(repo, { grade: 'blocked' });
  assert.equal(bare.status, 0, bare.stderr);
  const [withReviewers, without] = readRows(repo);
  assert.deepEqual(withReviewers.codeReviewers, ['claude', 'gemini']);
  assert.equal(withReviewers.verifierFamily, null);
  assert.deepEqual(without.codeReviewers, []);
});

test('summary folds the verify-skill and code-review notes into existing lines; old rows print neither', () => {
  const repo = workRepo({ tier: 'high' });
  const appended = append(repo, {
    grade: 'unit-tested',
    runs: [receipt()],
    extra: ['--code-reviewer', 'claude'],
  });
  assert.equal(appended.status, 0, appended.stderr);
  const lines = run(repo, ['summary']).stdout.trimEnd().split('\n');
  assert.ok(lines.length <= 12, lines.join('\n'));
  assert.ok(lines.includes('Grade: unit-tested (no verify skill)'), lines.join('\n'));
  assert.ok(
    lines.includes('Implementer: grok; verifier: (none); code review: claude'),
    lines.join('\n'),
  );

  tamperLastRow(repo, (row) => {
    delete row.verifySkill;
    delete row.codeReviewers;
  });
  const old = run(repo, ['summary']).stdout.trimEnd().split('\n');
  assert.ok(old.includes('Grade: unit-tested'), old.join('\n'));
  assert.ok(old.includes('Implementer: grok; verifier: (none)'), old.join('\n'));
});

test('append creates a self-ignoring gitignore and verdicts stay untracked', () => {
  const repo = workRepo();
  const appended = append(repo);
  assert.equal(appended.status, 0, appended.stderr);
  const ignore = fs.readFileSync(path.join(repo, '.sjujperpowers', '.gitignore'), 'utf8');
  assert.equal(ignore, '/.gitignore\n/verdicts.jsonl\n');
  assert.ok(fs.existsSync(ledgerPath(repo)));
  jj(repo, ['status']);
  const listed = jj(repo, ['file', 'list']).stdout;
  assert.equal(listed.includes('verdicts.jsonl'), false, listed);
  assert.equal(listed.includes('.gitignore'), false, listed);
  assert.ok(listed.includes('a.txt'));
});

test('existing gitignore lacking the verdicts entry exits 2 and is not modified', () => {
  const repo = workRepo();
  const dir = path.join(repo, '.sjujperpowers');
  const prior = '# keep\n';
  fs.writeFileSync(path.join(dir, '.gitignore'), prior);
  const appended = append(repo);
  assert.equal(appended.status, 2);
  assert.match(appended.stderr, /verdicts\.jsonl/);
  assert.equal(fs.readFileSync(path.join(dir, '.gitignore'), 'utf8'), prior);
  assert.equal(fs.existsSync(ledgerPath(repo)), false);

  const negated = '/verdicts.jsonl\n!/verdicts.jsonl\n';
  fs.writeFileSync(path.join(dir, '.gitignore'), negated);
  const negation = append(repo);
  assert.equal(negation.status, 2);
  assert.match(negation.stderr, /negation/);
  assert.match(negation.stderr, /un-ignore/);
  assert.equal(fs.readFileSync(path.join(dir, '.gitignore'), 'utf8'), negated);
  assert.equal(fs.existsSync(ledgerPath(repo)), false);
});

test('append refuses a ledger already tracked in @ and names the untrack recovery', () => {
  const repo = workRepo();
  write(repo, '.sjujperpowers/verdicts.jsonl', '');
  jj(repo, ['commit', '-m', 'track the ledger']);
  const listed = jj(repo, ['file', 'list', '-r', '@', '--', 'root-file:".sjujperpowers/verdicts.jsonl"']).stdout;
  assert.ok(listed.includes('verdicts.jsonl'), listed);
  const refused = append(repo);
  assert.equal(refused.status, 2, refused.stdout);
  assert.match(refused.stderr, /jj file untrack \.sjujperpowers\/verdicts\.jsonl/);
  assert.equal(fs.readFileSync(ledgerPath(repo), 'utf8'), '');
});

test('append rejects an unknown grade', () => {
  const repo = workRepo();
  const bad = append(repo, { grade: 'looks-fine', runs: [receipt()] });
  assert.equal(bad.status, 2);
  assert.equal(fs.existsSync(ledgerPath(repo)), false);
});

test('check is current, void after describe, void after main moves, missing otherwise', () => {
  const repo = workRepo();
  const missing = run(repo, ['check']);
  assert.equal(missing.status, 1);
  assert.equal(JSON.parse(missing.stdout).status, 'missing');

  const appended = append(repo, { verifier: 'claude', runs: [receipt()] });
  assert.equal(appended.status, 0, appended.stderr);
  const current = check(repo);
  assert.equal(current.status, 0, JSON.stringify(current.json));
  assert.equal(current.json.status, 'current');
  assert.equal(current.json.row.grade, 'blocked');
  assert.equal(current.json.row.verifierFamily, 'claude');
  assert.equal(current.json.row.implementerFamily, 'grok');

  const summary = run(repo, ['summary']);
  assert.equal(summary.status, 0, summary.stderr);
  assert.ok(summary.stdout.trim().split('\n').length <= 12, summary.stdout);
  assert.match(summary.stdout, /current/);
  assert.match(summary.stdout, /blocked/);
  assert.match(summary.stdout, /^Self-reported:/m);

  const multiline = append(repo, { verifier: 'claude', runs: [receipt('echo one\ntwo')] });
  assert.equal(multiline.status, 0, multiline.stderr);
  const escaped = run(repo, ['summary']);
  assert.equal(escaped.status, 0, escaped.stderr);
  assert.ok(escaped.stdout.trim().split('\n').length <= 12, escaped.stdout);
  assert.ok(escaped.stdout.includes('echo one\\ntwo'), escaped.stdout);

  jj(repo, ['describe', '-m', 'work rewritten']);
  const rewritten = check(repo);
  assert.equal(rewritten.status, 1);
  assert.equal(rewritten.json.status, 'void');
  assert.ok(rewritten.json.reasons.length > 0);

  const repo2 = workRepo();
  const change = rev(repo2, '@', 'change_id');
  assert.equal(append(repo2, { grade: 'failed' }).status, 0);
  jj(repo2, ['new', 'main', '-m', 'trunk moves']);
  write(repo2, 'trunk.txt', 't\n');
  jj(repo2, ['bookmark', 'set', 'main', '-r', '@']);
  const moved = check(repo2, ['--head', change]);
  assert.equal(moved.status, 1, JSON.stringify(moved.json));
  assert.equal(moved.json.status, 'void');
  assert.ok(moved.json.reasons.some((reason) => /policyCommit|range|trunk/i.test(reason)));
});

test('low tier with a declared test command appends and records the policy', () => {
  const repo = workRepo();
  const appended = append(repo, { grade: 'unit-tested', runs: [receipt()] });
  assert.equal(appended.status, 0, appended.stderr);
  const [row] = readRows(repo);
  assert.equal(row.verifierFamily, null);
  assert.equal(row.tier, 'low');
  assert.equal(row.computedTier, 'low');
  assert.equal(row.testCommand, TEST_COMMAND);
  assert.equal(row.protected, false);
  assert.deepEqual(row.protectedPaths, []);
  assert.equal(row.policyCommit, rev(repo, 'main', 'commit_id'));
  assert.equal(row.range.from, rev(repo, 'main', 'commit_id'));
  assert.equal(row.range.to, row.commit);
  assert.deepEqual(row.runs, [{ command: TEST_COMMAND, exit: 0, evidence: 'ok' }]);
  assert.equal(check(repo).status, 0);
});

test('unit-tested and above fail when risk.toml on main declares no test command', () => {
  const repo = workRepo({ test: '', verify: true });
  for (const grade of ['unit-tested', 'behavior-tested', 'live-verified']) {
    const result = append(repo, { grade, verifier: 'claude', runs: [receipt()] });
    assert.equal(result.status, 2, `${grade}: ${result.stdout}`);
    assert.match(result.stderr, /no test command/);
  }
  // A missing declared `test` is a setup gap, not missing evidence: the grade
  // stops at type-check-only even with a verify skill.
  const typeCheck = append(repo, { grade: 'type-check-only' });
  assert.equal(typeCheck.status, 0, typeCheck.stderr);
  const summary = run(repo, ['summary']);
  assert.match(summary.stdout, /Grade: type-check-only \(no declared test\)/);
});

test('with a verify skill, a missing declared test receipt leaves the grade blocked', () => {
  const repo = workRepo({ verify: true });
  const typeCheck = append(repo, { grade: 'type-check-only' });
  assert.equal(typeCheck.status, 2, typeCheck.stdout);
  assert.match(typeCheck.stderr, new RegExp(TEST_COMMAND));
  const substituted = append(repo, { grade: 'type-check-only', runs: [receipt('true')] });
  assert.equal(substituted.status, 2, substituted.stdout);
  assert.equal(fs.existsSync(ledgerPath(repo)), false);
  assert.equal(append(repo, { grade: 'blocked' }).status, 0);
});

test('without a verify skill the setup gaps still allow type-check-only', () => {
  for (const options of [{ test: '' }, { test: TEST_COMMAND }]) {
    const repo = workRepo(options);
    const result = append(repo, { grade: 'type-check-only' });
    assert.equal(result.status, 0, result.stderr);
    assert.match(run(repo, ['summary']).stdout, /\(no verify skill(?:; no declared test)?\)/);
  }
});

test('a risk.toml-less repo cannot reach unit-tested either', () => {
  const repo = initRepo();
  jj(repo, ['new', '-m', 'work']);
  write(repo, 'a.txt', 'a\n');
  const result = append(repo, { grade: 'unit-tested', verifier: 'claude', runs: [receipt('true')] });
  assert.equal(result.status, 2);
  assert.match(result.stderr, /no test command; grade stops at type-check-only/);
});

test('unit-tested needs a passing run of the exact declared command', () => {
  const repo = workRepo({ verify: true });
  for (const [label, runs, pattern] of [
    ['no runs', [], new RegExp(TEST_COMMAND)],
    ['substituted command', [receipt('true')], new RegExp(TEST_COMMAND)],
    ['declared command with extra args', [receipt(`${TEST_COMMAND} --only-fast`)], new RegExp(TEST_COMMAND)],
    ['declared command that failed', [receipt(TEST_COMMAND, 1)], new RegExp(TEST_COMMAND)],
    ['passing substitute next to failing real run', [receipt('true'), receipt(TEST_COMMAND, 1)], new RegExp(TEST_COMMAND)],
  ]) {
    const result = append(repo, { grade: 'unit-tested', runs });
    assert.equal(result.status, 2, `${label}: ${result.stdout}`);
    assert.match(result.stderr, pattern, label);
  }
  assert.equal(fs.existsSync(ledgerPath(repo)), false);

  const ok = append(repo, {
    grade: 'behavior-tested',
    runs: [receipt('true'), receipt(TEST_COMMAND, 1), receipt(TEST_COMMAND, 0)],
  });
  assert.equal(ok.status, 0, ok.stderr);
  assert.equal(readRows(repo).length, 1);
});

test('a stack that edits risk.toml test still has to run the command declared on main', () => {
  const repo = workRepo();
  write(repo, '.sjujperpowers/risk.toml', policy({ test: 'true' }));
  const substituted = append(repo, { grade: 'unit-tested', verifier: 'claude', runs: [receipt('true')] });
  assert.equal(substituted.status, 2, substituted.stdout);
  assert.match(substituted.stderr, new RegExp(TEST_COMMAND));
  const declared = append(repo, { grade: 'unit-tested', verifier: 'claude', runs: [receipt()] });
  assert.equal(declared.status, 0, declared.stderr);
  const [row] = readRows(repo);
  assert.equal(row.testCommand, TEST_COMMAND);
  assert.equal(row.protected, true);
  assert.ok(row.protectedPaths.includes('.sjujperpowers/risk.toml'));
});

test('--raise high on a low stack is recorded, needs a verifier, and stays current', () => {
  const repo = workRepo({ verify: true });
  const same = append(repo, { grade: 'unit-tested', runs: [receipt()], extra: ['--raise', 'high'] });
  assert.equal(same.status, 2);
  assert.match(same.stderr, /different-family/);
  assert.equal(fs.existsSync(ledgerPath(repo)), false);

  const raised = append(repo, {
    grade: 'unit-tested',
    verifier: 'claude',
    runs: [receipt()],
    extra: ['--raise', 'high'],
  });
  assert.equal(raised.status, 0, raised.stderr);
  const [row] = readRows(repo);
  assert.equal(row.tier, 'high');
  assert.equal(row.computedTier, 'low');
  const current = check(repo);
  assert.equal(current.status, 0, JSON.stringify(current.json));
  assert.equal(current.json.status, 'current');
  const summary = run(repo, ['summary']);
  assert.match(summary.stdout, /Tier: high \(raised from low\)/);
});

test('--raise cannot lower the computed tier', () => {
  const repo = workRepo({ tier: 'high' });
  const result = append(repo, { verifier: 'claude', extra: ['--raise', 'low'] });
  assert.equal(result.status, 0, result.stderr);
  assert.equal(readRows(repo)[0].tier, 'high');
});

test('tampering the stored tier from high to low voids the verdict', () => {
  const repo = workRepo({ tier: 'high' });
  const appended = append(repo, { verifier: 'claude' });
  assert.equal(appended.status, 0, appended.stderr);
  assert.equal(check(repo).status, 0);
  tamperLastRow(repo, (row) => {
    assert.equal(row.tier, 'high');
    row.tier = 'low';
    row.computedTier = 'low';
  });
  const voided = check(repo);
  assert.equal(voided.status, 1);
  assert.equal(voided.json.status, 'void');
  assert.deepEqual(voided.json.reasons.length, 1, JSON.stringify(voided.json.reasons));
  assert.match(voided.json.reasons[0], /tier low is below the recomputed tier high/);
});

test('tampering protected from true to false voids the verdict', () => {
  const repo = workRepo();
  write(repo, 'devenv.nix', '{}\n');
  assert.equal(append(repo).status, 0);
  assert.equal(check(repo).status, 0);
  tamperLastRow(repo, (row) => {
    assert.equal(row.protected, true);
    row.protected = false;
  });
  const voided = check(repo);
  assert.equal(voided.status, 1);
  assert.equal(voided.json.status, 'void');
  assert.equal(voided.json.reasons.length, 1, JSON.stringify(voided.json.reasons));
  assert.match(voided.json.reasons[0], /protected does not match/);
});

test('tampering protectedPaths by dropping one voids the verdict', () => {
  const repo = workRepo();
  write(repo, 'devenv.nix', '{}\n');
  write(repo, '.agents/skills/verify-x/SKILL.md', 'skill\n');
  assert.equal(append(repo).status, 0);
  assert.equal(check(repo).status, 0);
  tamperLastRow(repo, (row) => {
    assert.deepEqual(row.protectedPaths, ['.agents/skills/verify-x/SKILL.md', 'devenv.nix']);
    row.protectedPaths = ['devenv.nix'];
  });
  const voided = check(repo);
  assert.equal(voided.status, 1);
  assert.equal(voided.json.status, 'void');
  assert.equal(voided.json.reasons.length, 1, JSON.stringify(voided.json.reasons));
  assert.match(voided.json.reasons[0], /protectedPaths do not match/);
});

test('a verdict recorded before a protected path was added is void after it is', () => {
  const repo = workRepo();
  assert.equal(append(repo).status, 0);
  assert.equal(check(repo).json.status, 'current');
  write(repo, 'devenv.nix', '{}\n');
  const voided = check(repo);
  assert.equal(voided.status, 1);
  assert.equal(voided.json.status, 'void');
  assert.ok(voided.json.reasons.some((reason) => /protected/.test(reason)));
});

test('live-verified needs a different-family verifier at every tier', () => {
  const repo = workRepo({ verify: true });
  for (const [label, verifier] of [['no verifier', undefined], ['same family', 'grok']]) {
    const refused = append(repo, { grade: 'live-verified', verifier, runs: [receipt()] });
    assert.equal(refused.status, 2, `${label}: ${refused.stdout}`);
    assert.match(refused.stderr, /live-verified needs a different-family verifier/, label);
  }
  assert.equal(fs.existsSync(ledgerPath(repo)), false);
  const ok = append(repo, { grade: 'live-verified', verifier: 'claude', runs: [receipt()] });
  assert.equal(ok.status, 0, ok.stderr);
  assert.equal(check(repo).json.status, 'current');
});

test('the latest run of the declared test decides the grade', () => {
  const repo = workRepo();
  const passThenFail = append(repo, {
    grade: 'unit-tested',
    runs: [receipt(TEST_COMMAND, 0), receipt(TEST_COMMAND, 1)],
  });
  assert.equal(passThenFail.status, 2, passThenFail.stdout);
  assert.match(passThenFail.stderr, /latest run of required command/);
  assert.equal(fs.existsSync(ledgerPath(repo)), false);

  // A failing run is the only grade a failing latest run allows; blocked does not fit either.
  const blocked = append(repo, { grade: 'blocked', runs: [receipt(TEST_COMMAND, 1)] });
  assert.equal(blocked.status, 2, blocked.stdout);
  const failed = append(repo, {
    grade: 'failed',
    runs: [receipt(TEST_COMMAND, 0), receipt(TEST_COMMAND, 1)],
  });
  assert.equal(failed.status, 0, failed.stderr);

  const failThenPass = append(repo, {
    grade: 'unit-tested',
    runs: [receipt(TEST_COMMAND, 1), receipt(TEST_COMMAND, 0)],
  });
  assert.equal(failThenPass.status, 0, failThenPass.stderr);
  assert.equal(check(repo).json.status, 'current');
});

test('a failed hk-check blocks every grade but failed when the head tracks hk.pkl', () => {
  const repo = workRepo();
  write(repo, 'hk.pkl', 'amends "package://example"\n');
  const refused = append(repo, {
    grade: 'unit-tested',
    runs: [receipt('hk-check', 1), receipt()],
  });
  assert.equal(refused.status, 2, refused.stdout);
  assert.match(refused.stderr, /hk-check/);
  assert.equal(fs.existsSync(ledgerPath(repo)), false);
  const failed = append(repo, { grade: 'failed', runs: [receipt('hk-check', 1), receipt()] });
  assert.equal(failed.status, 0, failed.stderr);
  const recovered = append(repo, {
    grade: 'unit-tested',
    runs: [receipt('hk-check', 1), receipt('hk-check', 0), receipt()],
  });
  assert.equal(recovered.status, 0, recovered.stderr);
  assert.equal(readRows(repo).at(-1).hkRequired, true);
  assert.equal(check(repo).json.status, 'current');
});

test('hk-check is exploratory when the head tracks no hk.pkl; other failing commands never constrain', () => {
  const repo = workRepo();
  const noHk = append(repo, {
    grade: 'unit-tested',
    runs: [receipt('hk-check', 1), receipt()],
  });
  assert.equal(noHk.status, 0, noHk.stderr);
  const exploratory = append(repo, {
    grade: 'unit-tested',
    runs: [receipt(), receipt('node scratch.mjs', 1)],
  });
  assert.equal(exploratory.status, 0, exploratory.stderr);
  assert.equal(check(repo).json.status, 'current');
});

test('check voids a stored row whose range.to is not the head commit', () => {
  const repo = workRepo();
  assert.equal(append(repo, { grade: 'unit-tested', runs: [receipt()] }).status, 0);
  assert.equal(check(repo).json.status, 'current');
  tamperLastRow(repo, (row) => {
    row.range.to = '0'.repeat(40);
  });
  const voided = check(repo);
  assert.equal(voided.status, 1);
  assert.equal(voided.json.status, 'void');
  assert.deepEqual(voided.json.reasons, ['range.to does not match head']);
});

test('check voids stored rows whose grade contradicts their own fields or receipts', () => {
  const edits = [
    ['live-verified with no verifier or runs', { verify: true, tier: 'high', grade: 'blocked' }, (row) => {
      row.grade = 'live-verified';
      row.verifierFamily = null;
      row.runs = [];
    }, /different-family verifier/],
    ['live-verified with no verifier at low tier', { verify: true, grade: 'unit-tested', runs: [receipt()] }, (row) => {
      row.grade = 'live-verified';
    }, /live-verified needs a different-family verifier/],
    ['passing grade after a failing latest run', { grade: 'unit-tested', runs: [receipt()] }, (row) => {
      row.runs.push({ command: TEST_COMMAND, exit: 1 });
    }, /latest run of required command/],
    ['declared test dropped from the row', { grade: 'unit-tested', runs: [receipt()] }, (row) => {
      row.testCommand = null;
      row.runs = [];
    }, /testCommand does not match/],
    ['verifySkill flipped off', { verify: true, grade: 'blocked' }, (row) => {
      row.verifySkill = false;
      row.grade = 'behavior-tested';
    }, /verifySkill does not match/],
    ['hkRequired dropped to hide a failed hk-check', { grade: 'failed', runs: [receipt('hk-check', 1)], hk: true }, (row) => {
      row.hkRequired = false;
      row.grade = 'unit-tested';
      row.runs.push(JSON.parse(receipt()));
    }, /hkRequired does not match/],
    ['row from before the validator (no hkRequired)', { grade: 'blocked' }, (row) => {
      delete row.hkRequired;
    }, /hkRequired does not match/],
  ];
  for (const [label, setup, edit, pattern] of edits) {
    const repo = workRepo({ verify: setup.verify, tier: setup.tier });
    if (setup.hk) write(repo, 'hk.pkl', 'x\n');
    const appended = append(repo, {
      grade: setup.grade,
      verifier: setup.tier === 'high' ? 'claude' : undefined,
      runs: setup.runs,
    });
    assert.equal(appended.status, 0, `${label}: ${appended.stderr}`);
    assert.equal(check(repo).json.status, 'current', label);
    tamperLastRow(repo, edit);
    const voided = check(repo);
    assert.equal(voided.status, 1, label);
    assert.equal(voided.json.status, 'void', label);
    assert.ok(voided.json.reasons.some((reason) => pattern.test(reason)), `${label}: ${voided.json.reasons}`);
  }
});

test('a head that tracks hk.pkl needs an hk-check receipt from type-check-only up', () => {
  const repo = workRepo();
  write(repo, 'hk.pkl', 'amends "package://example"\n');
  for (const grade of ['type-check-only', 'unit-tested']) {
    const refused = append(repo, { grade, runs: [receipt()] });
    assert.equal(refused.status, 2, `${grade}: ${refused.stdout}`);
    assert.match(refused.stderr, /needs a passing run of hk-check/, grade);
  }
  assert.equal(fs.existsSync(ledgerPath(repo)), false);
  // The ledger matches the literal command string: a path-form receipt is not an hk-check run.
  const pathForm = append(repo, { grade: 'unit-tested', runs: [receipt('/skills/verifying-by-risk/scripts/hk-check', 0), receipt()] });
  assert.equal(pathForm.status, 2, pathForm.stdout);
  assert.match(pathForm.stderr, /needs a passing run of hk-check/);
  assert.equal(append(repo, { grade: 'blocked', runs: [receipt()] }).status, 0);
  const ok = append(repo, { grade: 'unit-tested', runs: [receipt('hk-check', 0), receipt()] });
  assert.equal(ok.status, 0, ok.stderr);
  assert.equal(check(repo).json.status, 'current');

  // A stored row whose hk-check receipt was removed is void.
  tamperLastRow(repo, (row) => {
    row.runs = row.runs.filter((item) => item.command !== 'hk-check');
  });
  const voided = check(repo);
  assert.equal(voided.status, 1);
  assert.equal(voided.json.status, 'void');
  assert.ok(voided.json.reasons.some((reason) => /needs a passing run of hk-check/.test(reason)));
});
