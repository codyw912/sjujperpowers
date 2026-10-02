#!/usr/bin/env node
import fs from 'node:fs';
import path from 'node:path';
import {
  GRADES,
  TIERS,
  fail,
  flag,
  flags,
  jj,
  repoArg,
  snapshot,
  root,
} from './jj.mjs';
import { classify } from './classify.mjs';

const argv = process.argv.slice(2);
const repo = repoArg(argv);
const valued = new Set([
  '--repo',
  '--raise',
  '--grade',
  '--implementer-family',
  '--verifier-family',
  '--run',
  '--code-reviewer',
  '--head',
]);
let command;
for (let i = 0; i < argv.length; i += 1) {
  if (valued.has(argv[i])) {
    i += 1;
    continue;
  }
  if (!argv[i].startsWith('--')) {
    command = argv[i];
    break;
  }
}
if (!['append', 'check', 'summary'].includes(command))
  fail('usage: verdict.mjs append|check|summary');
snapshot(repo);
const workspace = root(repo);
const ledgerDir = path.join(workspace, '.sjujperpowers');
const ledger = path.join(ledgerDir, 'verdicts.jsonl');
const ignorePath = path.join(ledgerDir, '.gitignore');
const IGNORE = '/.gitignore\n/verdicts.jsonl\n';

function readRows() {
  if (!fs.existsSync(ledger)) return [];
  return fs
    .readFileSync(ledger, 'utf8')
    .split('\n')
    .filter(Boolean)
    .map((line, index) => {
      try {
        return JSON.parse(line);
      } catch {
        fail(`malformed verdicts.jsonl line ${index + 1}`);
      }
    });
}

function latestFor(change) {
  const rows = readRows().filter((row) => row.change === change);
  return rows.length ? rows[rows.length - 1] : null;
}

function ensureIgnored() {
  if (!fs.existsSync(ignorePath)) {
    fs.mkdirSync(ledgerDir, { recursive: true });
    fs.writeFileSync(ignorePath, IGNORE);
    return;
  }
  const text = fs.readFileSync(ignorePath, 'utf8');
  const lines = text.split(/\r?\n/);
  if (lines.some((line) => line.trim().startsWith('!'))) {
    fail(
      'negations are not allowed in .sjujperpowers/.gitignore; they can un-ignore the ledger',
    );
  }
  const covered = lines.some(
    (line) => line.trim() === '/verdicts.jsonl' || line.trim() === 'verdicts.jsonl',
  );
  if (!covered) {
    fail('add /verdicts.jsonl to .sjujperpowers/.gitignore before appending a verdict');
  }
}

// An ignore entry does not untrack a file. A tracked ledger changes @ on the
// next snapshot, which would void the verdict this row records.
function refuseTrackedLedger() {
  const listed = jj(repo, ['file', 'list', '-r', '@', '--', 'root-file:".sjujperpowers/verdicts.jsonl"']);
  if (listed.stdout.trim()) {
    fail(
      '.sjujperpowers/verdicts.jsonl is tracked in @, so appending would change @ and void the verdict. With the ignore entry in place, run: jj file untrack .sjujperpowers/verdicts.jsonl',
    );
  }
}

function hasHkPkl(commit) {
  return jj(repo, ['file', 'list', '-r', commit, '--', 'root-file:"hk.pkl"']).stdout.trim() !== '';
}

// One consistency check for a row's grade against its own receipts, verifier,
// and setup-gap facts. append refuses on the first problem; check/evaluate
// voids a stored row on any. The required commands are the declared test and,
// when the head tracks an hk.pkl, hk-check; the latest run of each is its
// result, and runs of other commands never constrain the grade.
function consistency({ grade, tier, testCommand, verifySkill, hkRequired, implementer, verifier, runs }) {
  if (!GRADES.includes(grade)) return [`grade must be one of ${GRADES.join(', ')}`];
  if (
    !Array.isArray(runs) ||
    runs.some((run) => typeof run?.command !== 'string' || typeof run.exit !== 'number')
  )
    return ['runs must be a list of {command, exit}'];
  const problems = [];
  const rank = GRADES.indexOf(grade);
  const differentFamily = Boolean(verifier) && verifier !== implementer;
  // behavior-tested and live-verified need verify recipes; without a verify skill there are none.
  if (!verifySkill && (grade === 'behavior-tested' || grade === 'live-verified'))
    problems.push('no verify skill: grade stops at unit-tested');
  // Code review never satisfies the verifier. Without a verify skill there is nothing for a
  // verifier to run, so high tier may reach unit-tested without one.
  if (tier === 'high' && verifySkill && grade !== 'failed' && grade !== 'blocked' && !differentFamily)
    problems.push('high tier needs a different-family verifier');
  else if (grade === 'live-verified' && !differentFamily)
    problems.push('live-verified needs a different-family verifier');
  const latest = (command) => runs.findLast((run) => run.command === command);
  const required = [testCommand, hkRequired ? 'hk-check' : null].filter(Boolean);
  const failing = required.find((command) => latest(command)?.exit !== 0 && latest(command));
  if (failing && grade !== 'failed') {
    problems.push(
      `grade ${grade} contradicts the latest run of required command ${failing} (exit ${latest(failing).exit}); only failed fits`,
    );
  }
  // A missing `test` declaration is a setup gap: the grade stops at
  // type-check-only either way. A declared command with no passing receipt is
  // missing required evidence: blocked when a verify skill exists, and still
  // just capped when there is none.
  if (rank >= GRADES.indexOf('unit-tested') && !testCommand) {
    problems.push('risk.toml on trunk declares no test command; grade stops at type-check-only');
  } else if (
    !failing &&
    testCommand &&
    !latest(testCommand) &&
    (rank >= GRADES.indexOf('unit-tested') || (verifySkill && grade === 'type-check-only'))
  ) {
    problems.push(`grade ${grade} needs a passing run of the declared test command: ${testCommand}`);
  }
  // hk-check is the static check of a repo that tracks an hk.pkl, so type-check-only
  // and above need its receipt; a missing one is missing evidence, which fits blocked.
  if (hkRequired && !failing && rank >= GRADES.indexOf('type-check-only') && !latest('hk-check')) {
    problems.push(`grade ${grade} needs a passing run of hk-check: the head tracks an hk.pkl`);
  }
  return problems;
}

function append() {
  if (argv.includes('--classification'))
    fail('append classifies the stack itself; it does not take --classification');
  const grade = flag(argv, '--grade');
  const implementer = flag(argv, '--implementer-family');
  const verifier = flag(argv, '--verifier-family') ?? null;
  const codeReviewers = flags(argv, '--code-reviewer');
  if (!GRADES.includes(grade)) fail(`grade must be one of ${GRADES.join(', ')}`);
  if (!implementer) fail('append requires --implementer-family');
  const runs = flags(argv, '--run').map((raw) => {
    let parsed;
    try {
      parsed = JSON.parse(raw);
    } catch {
      fail('--run must be JSON');
    }
    if (typeof parsed.command !== 'string' || typeof parsed.exit !== 'number') {
      fail('--run needs command and exit');
    }
    const run = { command: parsed.command, exit: parsed.exit };
    if (parsed.evidence !== undefined) run.evidence = parsed.evidence;
    return run;
  });
  const current = classify(repo, { head: flag(argv, '--head'), raise: flag(argv, '--raise') });
  const facts = {
    grade,
    tier: current.tier,
    testCommand: current.testCommand,
    verifySkill: current.verifySkill,
    hkRequired: hasHkPkl(current.head.commit),
    implementer,
    verifier,
    runs,
  };
  const [contradiction] = consistency(facts);
  if (contradiction) fail(contradiction);
  ensureIgnored();
  refuseTrackedLedger();
  const row = {
    change: current.head.change,
    commit: current.head.commit,
    range: current.range,
    policyCommit: current.policy.commit,
    testCommand: current.testCommand,
    tier: current.tier,
    computedTier: current.computedTier,
    protected: current.protected,
    protectedPaths: current.protectedPaths,
    grade,
    runs,
    implementerFamily: implementer,
    verifierFamily: verifier,
    codeReviewers,
    verifySkill: current.verifySkill,
    hkRequired: facts.hkRequired,
    timestamp: new Date().toISOString(),
  };
  fs.mkdirSync(ledgerDir, { recursive: true });
  fs.appendFileSync(ledger, `${JSON.stringify(row)}\n`);
}

// A row is current only if a fresh classification at the same head agrees with
// it. The tier may have been raised, so it only has to be at least the
// recomputed one; protected and protectedPaths must match exactly.
function evaluate(headArg) {
  const current = classify(repo, { head: headArg });
  const head = current.head;
  const row = latestFor(head.change);
  if (!row) return { status: 'missing', reasons: ['no verdict for this change'], row: null, head };
  const reasons = [];
  if (row.commit !== head.commit) reasons.push('commit does not match head');
  if (row.range?.from !== current.range.from)
    reasons.push('range.from is not the current fork point of trunk and head');
  if (row.range?.to !== head.commit) reasons.push('range.to does not match head');
  if (row.policyCommit !== current.policy.commit)
    reasons.push('policyCommit is not the current trunk commit');
  if (!TIERS.includes(row.tier) || TIERS.indexOf(row.tier) < TIERS.indexOf(current.computedTier))
    reasons.push(`tier ${row.tier} is below the recomputed tier ${current.computedTier}`);
  if (row.protected !== current.protected) reasons.push('protected does not match reclassification');
  if (JSON.stringify(row.protectedPaths) !== JSON.stringify(current.protectedPaths))
    reasons.push('protectedPaths do not match reclassification');
  // The validator reads testCommand, verifySkill, and hkRequired from the row, so
  // each must still be what a fresh derivation at this head gives.
  if (row.testCommand !== current.testCommand)
    reasons.push('testCommand does not match the declaration on trunk');
  if (row.verifySkill !== current.verifySkill) reasons.push('verifySkill does not match reclassification');
  if (row.hkRequired !== hasHkPkl(head.commit)) reasons.push('hkRequired does not match hk.pkl at head');
  for (const problem of consistency({
    grade: row.grade,
    tier: row.tier,
    testCommand: row.testCommand,
    verifySkill: row.verifySkill,
    hkRequired: row.hkRequired,
    implementer: row.implementerFamily,
    verifier: row.verifierFamily,
    runs: row.runs,
  }))
    reasons.push(`inconsistent row: ${problem}`);
  return { status: reasons.length ? 'void' : 'current', reasons, row, head };
}

const oneLine = (value) => String(value).replace(/\r/g, '\\r').replace(/\n/g, '\\n');

// Setup gaps are folded into the Grade line. A missing verifySkill (old row) or
// a missing testCommand field (undefined, not null) prints nothing for it.
function gradeNote(row) {
  const gaps = [
    row.verifySkill === false ? 'no verify skill' : '',
    row.testCommand === null ? 'no declared test' : '',
  ]
    .filter(Boolean)
    .join('; ');
  return gaps ? ` (${gaps})` : '';
}

if (command === 'append') append();
else if (command === 'check') {
  const result = evaluate(flag(argv, '--head'));
  process.stdout.write(
    `${JSON.stringify({ status: result.status, reasons: result.reasons, row: result.row })}\n`,
  );
  process.exit(result.status === 'current' ? 0 : 1);
} else {

  const result = evaluate(flag(argv, '--head'));
  const row = result.row;

  const lines = [
    `Verdict: ${result.status}`,
    row ? `Change: ${oneLine(row.change)}` : 'Change: (none)',
    row ? `Commit: ${oneLine(row.commit)}` : 'Commit: (none)',
    row
      ? `Tier: ${oneLine(row.tier)}${row.tier !== row.computedTier ? ` (raised from ${oneLine(row.computedTier)})` : ''}${row.protected ? ' protected' : ''}`
      : 'Tier: (none)',
    row ? `Grade: ${oneLine(row.grade)}${gradeNote(row)}` : 'Grade: (none)',
    row ? `Range: ${oneLine(row.range.from)}..${oneLine(row.range.to)}` : 'Range: (none)',
    row ? `Policy: ${oneLine(row.policyCommit)}` : 'Policy: (none)',
  ];
  if (row) {
    lines.push(
      `Implementer: ${oneLine(row.implementerFamily)}; verifier: ${row.verifierFamily ? oneLine(row.verifierFamily) : '(none)'}${row.codeReviewers?.length ? `; code review: ${row.codeReviewers.map(oneLine).join(', ')}` : ''}`,
    );
    const runs =
      (row.runs || []).map((run) => `${oneLine(run.command)} exit ${run.exit}`).join('; ') || '(none)';
    lines.push(`Runs: ${runs}`);
    lines.push('Self-reported: grade, runs, and model families (scripts check tier and paths)');
    if (result.reasons.length)
      lines.push(`Reasons: ${result.reasons.map(oneLine).join('; ')}`);
    if (row.protectedPaths?.length)
      lines.push(`Protected: ${row.protectedPaths.map(oneLine).join(', ')}`);
  } else {
    lines.push(`Reasons: ${result.reasons.map(oneLine).join('; ')}`);
  }
  process.stdout.write(`${lines.slice(0, 12).join('\n')}\n`);
  if (result.status === 'missing') process.exit(1);
}
