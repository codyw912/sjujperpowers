import { test } from 'node:test';
import assert from 'node:assert/strict';
import {
  classifyPaths,
  globToRegExp,
  parseRiskToml,
} from '../../skills/verifying-by-risk/scripts/policy.mjs';

const BASE = 'version = 1\ndefault = "medium"\n';

test('multi-line arrays, comments, and trailing commas parse', () => {
  const policy = parseRiskToml(`${BASE}protected = [
  "migrations/**", # schema
  "src/auth/**",
]

[[rule]]
paths = ["docs/**", "*.md"] # prose
tier = "low"
`);
  assert.deepEqual(
    policy.protected.map((item) => item.glob),
    ['migrations/**', 'src/auth/**'],
  );
  assert.deepEqual(
    policy.rules.map((rule) => [rule.tier, rule.globs.map((g) => g.glob)]),
    [['low', ['docs/**', '*.md']]],
  );
});

test('a # inside a string is not a comment', () => {
  const policy = parseRiskToml(`${BASE}protected = ["a#b/**"]\n`);
  assert.equal(policy.protected[0].glob, 'a#b/**');
});

test('malformed policies are rejected', () => {
  for (const [body, message] of [
    ['default = "low"\n', /version/],
    ['version = 1\n', /default/],
    ['version = 1\ndefault = low\n', /default/],
    ['version = "1"\ndefault = "low"\n', /version/],
    [`${BASE}[[rule]]\npaths = ["a"]\ntier = high\n`, /tier/],
    [`${BASE}default = "low"\n`, /duplicate/],
    [`${BASE}owner = "x"\n`, /unknown key/],
    [`${BASE}[[rule]]\npaths = ["a"]\ntier = "urgent"\n`, /tier/],
    [`${BASE}[[rule]]\ntier = "low"\n`, /paths/],
    [`${BASE}protected = ["a"\n`, /expected|unterminated/],
    [`${BASE}protected = ["a"] "b"\n`, /expected nl/],
  ]) {
    assert.throws(() => parseRiskToml(body), message, body);
  }
});

test('glob semantics', () => {
  const cases = [
    ['.hk/**', '.hk/base/rust.pkl', true],
    ['.hk/**', '.hk', false],
    ['*.md', 'README.md', true],
    ['*.md', 'docs/a.md', false],
    ['**/*.md', 'docs/a.md', true],
    ['**/*.md', 'a.md', true],
    ['.agents/skills/verify-*/scripts/**', '.agents/skills/verify-x/scripts/run.sh', true],
    ['.agents/skills/verify-*/scripts/**', '.agents/skills/verify-x/SKILL.md', false],
    ['src/a?.rs', 'src/ab.rs', true],
    ['src/a?.rs', 'src/a/.rs', false],
    ['.hk/**', '.hk/a\nb', true],
  ];
  for (const [glob, file, expected] of cases)
    assert.equal(globToRegExp(glob).test(file), expected, `${glob} ${file}`);
});

test('no policy is high even with no changed paths', () => {
  assert.equal(classifyPaths([], null).computedTier, 'high');
  assert.equal(
    classifyPaths([{ status: 'modified', from: 'a', to: 'a' }], null).computedTier,
    'high',
  );
});

test('highest tier wins and a rename counts both sides', () => {
  const policy = parseRiskToml(
    `${BASE}[[rule]]\npaths = ["docs/**"]\ntier = "low"\n[[rule]]\npaths = ["src/**"]\ntier = "high"\n`,
  );
  const result = classifyPaths([{ status: 'renamed', from: 'src/x.rs', to: 'docs/x.rs' }], policy);
  assert.equal(result.computedTier, 'high');
  assert.equal(
    classifyPaths([{ status: 'added', from: 'docs/a', to: 'docs/a' }], policy).computedTier,
    'low',
  );
});

test('top-level test command is parsed; absent means null', () => {
  assert.equal(parseRiskToml(`${BASE}test = "node --test tests/"\n`).testCommand, 'node --test tests/');
  assert.equal(parseRiskToml(BASE).testCommand, null);
  assert.equal(
    parseRiskToml(`${BASE}test = "cargo test --workspace # all"\n`).testCommand,
    'cargo test --workspace # all',
  );
});

test('test command must be a non-empty string, once, at the top level', () => {
  for (const body of [
    `${BASE}test = ""\n`,
    `${BASE}test = "   "\n`,
    `${BASE}test = ["node", "--test"]\n`,
    `${BASE}test = true\n`,
    `${BASE}test = 1\n`,
    `${BASE}test = "a"\ntest = "b"\n`,
    `${BASE}[[rule]]\npaths = ["a"]\ntier = "low"\ntest = "node --test"\n`,
  ]) {
    assert.throws(() => parseRiskToml(body), undefined, body);
  }
  for (const body of [`${BASE}test = true\n`, `${BASE}test = 1\n`])
    assert.throws(() => parseRiskToml(body), /test must be a quoted string/, body);
});

test('verification-skill, hk, and devenv files are built-in protected', () => {
  const policy = parseRiskToml(`${BASE}`);
  for (const file of [
    'devenv.nix',
    '.config/hk.pkl',
    '.claude/skills/verify-x',
    '.agents/skills/verify-x/SKILL.md',
    '.agents/skills/verify-x/features/a.md',
    '.agents/skills/verify-x/features/deep/b.md',
  ]) {
    const result = classifyPaths([{ status: 'modified', from: file, to: file }], policy);
    assert.equal(result.protected, true, file);
    assert.deepEqual(result.protectedPaths, [file]);
  }
  assert.equal(
    classifyPaths([{ status: 'added', from: '.hk/a\nb', to: '.hk/a\nb' }], policy).protected,
    true,
  );
  for (const file of ['devenv.nix.bak', '.agents/skills/other/SKILL.md', '.agents/skills/verify-x/README.md', '.claude/skills/other', '.config/hk.local.pkl']) {
    const result = classifyPaths([{ status: 'modified', from: file, to: file }], policy);
    assert.equal(result.protected, false, file);
  }
});

test('a protected path renamed away is still protected', () => {
  const result = classifyPaths(
    [{ status: 'renamed', from: 'devenv.nix', to: 'docs/devenv.txt' }],
    parseRiskToml(BASE),
  );
  assert.equal(result.protected, true);
  assert.deepEqual(result.protectedPaths, ['devenv.nix', 'docs/devenv.txt']);
});
