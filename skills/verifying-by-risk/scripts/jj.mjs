import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

export const TIERS = ['low', 'medium', 'high'];
export const GRADES = [
  'failed',
  'blocked',
  'type-check-only',
  'unit-tested',
  'behavior-tested',
  'live-verified',
];

export function fail(message, code = 2) {
  process.stderr.write(`${message}\n`);
  process.exit(code);
}

export function jj(repo, args, { allowFail = false } = {}) {
  const result = spawnSync('jj', ['-R', repo, '--quiet', ...args], { encoding: 'utf8' });
  if (result.error) fail(`jj ${args[0]}: ${result.error.message}`);
  if (result.status !== 0 && !allowFail) {
    fail((result.stderr || result.stdout || `jj ${args.join(' ')} failed`).trim());
  }
  return result;
}

export function rev(repo, revset, template) {
  const result = jj(repo, ['log', '-r', revset, '--no-graph', '-T', template], { allowFail: true });
  if (result.status !== 0) return null;
  return result.stdout;
}

export function root(repo) {
  const result = jj(repo, ['root']);
  return result.stdout.trim();
}

export function resolveCommit(repo, revset) {
  const id = rev(repo, revset, 'commit_id');
  if (!id) return null;
  const trimmed = id.trim();
  return trimmed.length === 40 ? trimmed : null;
}

export function flag(argv, name) {
  const index = argv.indexOf(name);
  if (index === -1) return undefined;
  const value = argv[index + 1];
  if (value === undefined || value.startsWith('--')) fail(`missing value for ${name}`);
  return value;
}

export function flags(argv, name) {
  const values = [];
  for (let i = 0; i < argv.length; i += 1) {
    if (argv[i] === name) {
      const value = argv[i + 1];
      if (value === undefined || value.startsWith('--')) fail(`missing value for ${name}`);
      values.push(value);
    }
  }
  return values;
}

export function repoArg(argv) {
  return flag(argv, '--repo') || process.cwd();
}

// Snapshot first so a file written just before this process cannot rewrite @ afterwards.
export function snapshot(repo) {
  jj(repo, ['status']);
}

// @ is empty when jj reports empty=true. Same rule as finishing-a-change-stack.
export function resolveHead(repo, requested) {
  const revset = requested || '@';
  let commit = resolveCommit(repo, revset);
  if (!commit) fail(`cannot resolve head ${requested || '@'}`);
  if (!requested && rev(repo, commit, 'empty').trim() === 'true') {
    commit = resolveCommit(repo, '@-');
    if (!commit) fail('cannot resolve @-');
  }
  const change = rev(repo, commit, 'change_id');
  if (!change || !change.trim()) fail(`cannot resolve change id for ${commit}`);
  return { commit, change: change.trim() };
}

const TRUNK_REV = fileURLToPath(
  new URL('../../starting-a-change/scripts/trunk-rev', import.meta.url),
);

// The local trunk bookmark, resolved by the same script finishing-a-change-stack
// uses, so the classified range and the stack finishing shows never differ.
export function resolveTrunk(repo) {
  const result = spawnSync('bash', [TRUNK_REV], { cwd: repo, encoding: 'utf8' });
  if (result.error) fail(`trunk-rev: ${result.error.message}`);
  if (result.status !== 0) fail((result.stderr || 'trunk-rev failed').trim());
  const [revset, bookmark] = result.stdout.trim().split(' ');
  const commit = resolveCommit(repo, revset);
  if (!commit) fail(`cannot resolve trunk ${revset}`);
  return { bookmark, commit };
}

export function forkPoint(repo, trunkCommit, headCommit) {
  const commit = resolveCommit(repo, `fork_point(${trunkCommit} | ${headCommit})`);
  if (!commit) fail('cannot resolve fork_point(trunk | head)');
  return commit;
}

export function changedPaths(repo, from, to) {
  const template =
    'json(status) ++ "\\t" ++ json(source.path()) ++ "\\t" ++ json(target.path()) ++ "\\n"';
  const result = jj(repo, ['diff', '--from', from, '--to', to, '-T', template]);
  const rows = [];
  for (const line of result.stdout.split('\n')) {
    if (!line) continue;
    const parts = line.split('\t');
    if (parts.length !== 3) fail(`unexpected jj diff line: ${line}`);
    rows.push({
      status: JSON.parse(parts[0]),
      from: JSON.parse(parts[1]),
      to: JSON.parse(parts[2]),
    });
  }
  return rows;
}

export function maxTier(left, right) {
  return TIERS.indexOf(left) >= TIERS.indexOf(right) ? left : right;
}
