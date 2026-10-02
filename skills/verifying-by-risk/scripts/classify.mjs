import {
  TIERS,
  fail,
  jj,
  resolveHead,
  resolveTrunk,
  resolveCommit,
  forkPoint,
  changedPaths,
  touchedPaths,
  maxTier,
} from './jj.mjs';
import { parseRiskToml, classifyPaths } from './policy.mjs';

const VERIFY_SKILL = 'root-glob:".agents/skills/verify-*/SKILL.md"';

// Trunk OR head: a stack that deletes trunk's verify skill gets no startup
// exception, and a stack that adds one has a skill to run.
function hasVerifySkill(repo, commit) {
  return jj(repo, ['file', 'list', '-r', commit, VERIFY_SKILL]).stdout.trim() !== '';
}

// Classify every pending change from the local trunk to head against the
// policy committed on trunk. The range, trunk, and policy are never inputs.
// Tier and protection come from the union of paths every commit in the range
// touched, so a protected path added and reverted later still counts: the
// intermediate commit is retained history.
export function classify(repo, { head: headArg, range: rangeArg, raise } = {}) {
  if (raise !== undefined && !TIERS.includes(raise)) fail('--raise must be low, medium, or high');
  const head = resolveHead(repo, headArg);
  const trunk = resolveTrunk(repo);
  const from = forkPoint(repo, trunk.commit, head.commit);
  if (from === head.commit) fail('nothing pending');

  if (rangeArg !== undefined) {
    const parts = rangeArg.split('..');
    if (parts.length !== 2 || !parts[0] || !parts[1]) fail('--range must be FROM..TO');
    const givenFrom = resolveCommit(repo, parts[0]);
    const givenTo = resolveCommit(repo, parts[1]);
    if (!givenFrom || !givenTo) fail(`cannot resolve --range ${rangeArg}`);
    if (givenFrom !== from || givenTo !== head.commit) {
      fail(`--range ${givenFrom}..${givenTo} does not match computed range ${from}..${head.commit}`);
    }
  }

  const rows = touchedPaths(repo, from, head.commit);
  const netPaths = changedPaths(repo, from, head.commit);
  const shown = jj(
    repo,
    ['file', 'show', '-r', trunk.commit, 'root:".sjujperpowers/risk.toml"'],
    { allowFail: true },
  );
  const policy = { bookmark: trunk.bookmark, commit: trunk.commit, riskToml: shown.status === 0 };
  let parsed = null;
  if (shown.status === 0) {
    try {
      parsed = parseRiskToml(shown.stdout);
    } catch (error) {
      policy.error = error.message;
    }
  }
  const classified = classifyPaths(rows, parsed);
  return {
    head,
    range: { from, to: head.commit },
    policy,
    testCommand: parsed?.testCommand ?? null,
    verifySkill: hasVerifySkill(repo, trunk.commit) || hasVerifySkill(repo, head.commit),
    tier: raise ? maxTier(classified.computedTier, raise) : classified.computedTier,
    computedTier: classified.computedTier,
    protected: classified.protected,
    protectedPaths: classified.protectedPaths,
    paths: classified.paths,
    netPaths,
  };
}
