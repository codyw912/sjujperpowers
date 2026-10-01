import { TIERS, maxTier } from './jj.mjs';

export const BUILTIN_PROTECTED = [
  'hk.pkl',
  '.config/hk.pkl',
  '.hk/**',
  'nix/hk.nix',
  'scripts/update-hk',
  '.sjujperpowers/risk.toml',
  '.agents/skills/verify-*/SKILL.md',
  '.agents/skills/verify-*/features/**',
  '.agents/skills/verify-*/scripts/**',
  '.claude/skills/verify-*',
  '.github/workflows/**',
  'devenv.nix',
  'devenv.yaml',
  'devenv.lock',
];

// ** matches across slashes; "dir/**" matches files under dir, not dir itself.
// * and ? do not match /. * matches a leading dot. Match is full-path anchored.
export function globToRegExp(glob) {
  let pattern = '^';
  for (let i = 0; i < glob.length; i += 1) {
    const char = glob[i];
    const next = glob[i + 1];
    if (char === '*' && next === '*') {
      const after = glob[i + 2];
      if (after === '/') {
        pattern += '(?:.*/)?';
        i += 2;
      } else {
        pattern += '.*';
        i += 1;
      }
      continue;
    }
    if (char === '*') {
      pattern += '[^/]*';
      continue;
    }
    if (char === '?') {
      pattern += '[^/]';
      continue;
    }
    if ('\\^$+?.()|{}[]'.includes(char)) pattern += `\\${char}`;
    else pattern += char;
  }
  return new RegExp(`${pattern}$`, 's');
}

// Tokenizer for the restricted risk.toml grammar: comments, bare keys,
// basic strings, bare integers/words, string arrays (may span lines), and
// [[rule]] headers.
function tokenize(text) {
  const tokens = [];
  let line = 1;
  let i = 0;
  while (i < text.length) {
    const char = text[i];
    if (char === '\n') {
      tokens.push({ type: 'nl', line });
      line += 1;
      i += 1;
    } else if (char === ' ' || char === '\t' || char === '\r') {
      i += 1;
    } else if (char === '#') {
      while (i < text.length && text[i] !== '\n') i += 1;
    } else if (text.startsWith('[[rule]]', i)) {
      tokens.push({ type: 'rule', line });
      i += 8;
    } else if ('[],='.includes(char)) {
      tokens.push({ type: char, line });
      i += 1;
    } else if (char === '"') {
      let value = '';
      i += 1;
      for (;;) {
        if (i >= text.length || text[i] === '\n')
          throw new Error(`unterminated string at line ${line}`);
        if (text[i] === '"') break;
        if (text[i] === '\\') {
          const escaped = { n: '\n', t: '\t', '\\': '\\', '"': '"' }[text[i + 1]];
          if (escaped === undefined) throw new Error(`bad escape at line ${line}`);
          value += escaped;
          i += 2;
        } else {
          value += text[i];
          i += 1;
        }
      }
      tokens.push({ type: 'string', value, line });
      i += 1;
    } else {
      const match = /^[A-Za-z0-9_-]+/.exec(text.slice(i));
      if (!match) throw new Error(`unexpected ${JSON.stringify(char)} at line ${line}`);
      tokens.push({ type: 'word', value: match[0], line });
      i += match[0].length;
    }
  }
  tokens.push({ type: 'nl', line });
  return tokens;
}

export function parseRiskToml(text) {
  const tokens = tokenize(text);
  let at = 0;
  const next = () => tokens[at++];
  const expect = (type) => {
    const token = next();
    if (token?.type !== type) throw new Error(`expected ${type} at line ${token?.line ?? 'end'}`);
    return token;
  };
  const value = () => {
    const token = next();
    if (token?.type === 'string' || token?.type === 'word')
      return { kind: token.type, value: token.value };
    if (token?.type !== '[') throw new Error(`expected value at line ${token?.line ?? 'end'}`);
    const items = [];
    for (;;) {
      while (tokens[at]?.type === 'nl') at += 1;
      if (tokens[at]?.type === ']') {
        at += 1;
        return { kind: 'array', value: items };
      }
      items.push(expect('string').value);
      while (tokens[at]?.type === 'nl') at += 1;
      if (tokens[at]?.type === ',') at += 1;
      else if (tokens[at]?.type !== ']')
        throw new Error(`expected , or ] at line ${tokens[at]?.line ?? 'end'}`);
    }
  };

  const top = {};
  const rules = [];
  let rule = null;
  while (at < tokens.length) {
    const token = next();
    if (token.type === 'nl') continue;
    if (token.type === 'rule') {
      rule = {};
      rules.push(rule);
      expect('nl');
      continue;
    }
    if (token.type !== 'word') throw new Error(`expected key at line ${token.line}`);
    expect('=');
    const target = rule ?? top;
    if (token.value in target)
      throw new Error(`duplicate key ${token.value} at line ${token.line}`);
    const assigned = value();
    const isScalar = (kind) => assigned.kind === kind;
    if (target === top && token.value === 'default' && !isScalar('string'))
      throw new Error(`default must be a quoted string at line ${token.line}`);
    if (target === top && token.value === 'version' && !isScalar('word'))
      throw new Error(`version must be a bare integer at line ${token.line}`);
    if (rule && token.value === 'tier' && !isScalar('string'))
      throw new Error(`rule tier must be a quoted string at line ${token.line}`);
    if (target === top && token.value === 'test' && !isScalar('string'))
      throw new Error(`test must be a quoted string at line ${token.line}`);
    target[token.value] = assigned.value;
    expect('nl');
  }

  for (const key of Object.keys(top)) {
    if (!['version', 'default', 'test', 'protected'].includes(key))
      throw new Error(`unknown key ${key}`);
  }
  if (top.version !== '1') throw new Error('missing version = 1');
  if (!TIERS.includes(top.default)) throw new Error('default must be low, medium, or high');
  if (top.test !== undefined && (typeof top.test !== 'string' || !top.test.trim()))
    throw new Error('test must be a non-empty string');
  const protectedGlobs = top.protected ?? [];
  if (!Array.isArray(protectedGlobs)) throw new Error('protected must be a string array');
  for (const item of rules) {
    for (const key of Object.keys(item)) {
      if (!['paths', 'tier'].includes(key)) throw new Error(`unknown rule key ${key}`);
    }
    if (!Array.isArray(item.paths)) throw new Error('rule paths must be a string array');
    if (!TIERS.includes(item.tier)) throw new Error('rule tier must be low, medium, or high');
  }
  return {
    defaultTier: top.default,
    testCommand: top.test ?? null,
    protected: protectedGlobs.map((glob) => ({ glob, re: globToRegExp(glob) })),
    rules: rules.map((item) => ({
      tier: item.tier,
      globs: item.paths.map((glob) => ({ glob, re: globToRegExp(glob) })),
    })),
  };
}

export function classifyPaths(rows, policy) {
  const builtin = BUILTIN_PROTECTED.map((glob) => globToRegExp(glob));
  const extra = policy?.protected?.map((item) => item.re) || [];
  const protectedRes = [...builtin, ...extra];
  const paths = rows.map((row) => {
    const sides = [...new Set([row.from, row.to].filter(Boolean))];
    const sideTier = (side) => {
      if (!policy) return 'high';
      const rule = policy.rules.find((item) => item.globs.some((glob) => glob.re.test(side)));
      return rule ? rule.tier : policy.defaultTier;
    };
    const tier = sides.reduce((current, side) => maxTier(current, sideTier(side)), 'low');
    const protectedHit = sides.some((side) => protectedRes.some((re) => re.test(side)));
    return { status: row.status, from: row.from, to: row.to, tier, protected: protectedHit };
  });
  const protectedPaths = [
    ...new Set(paths.filter((row) => row.protected).flatMap((row) => [row.from, row.to])),
  ].sort();
  const computedTier = policy
    ? paths.reduce((tier, row) => maxTier(tier, row.tier), 'low')
    : 'high';
  return { paths, protectedPaths, protected: protectedPaths.length > 0, computedTier };
}
