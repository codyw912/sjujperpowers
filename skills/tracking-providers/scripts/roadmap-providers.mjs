// Roadmap providers: one entry per provider, in documentation order.
// normalize(raw, invalid) receives a roadmap object that already passed the
// resolver's shared checks (object, known keys, registered provider) and
// returns the resolved roadmap object. invalid(field, message) builds the
// resolver's path-qualified error.

const TEAM_KEY = /^[A-Z][A-Z0-9]*$/;

function requireString(raw, field, invalid) {
  const value = raw[field];
  if (typeof value !== 'string' || value.trim() === '') {
    throw invalid(`roadmap.${field}`, 'must be a non-empty string');
  }
  return value.trim();
}

function rejectFields(raw, fields, provider, invalid) {
  for (const field of fields) {
    if (raw[field] !== undefined) {
      throw invalid(`roadmap.${field}`, `is not valid for provider ${provider}`);
    }
  }
}

const file = {
  name: 'file',
  normalize(raw, invalid) {
    rejectFields(raw, ['project', 'team'], 'file', invalid);
    return { provider: 'file' };
  },
};

const plane = {
  name: 'plane',
  fields: { required: ['project'], optional: [] },
  referencePattern: /^plane:[A-Z0-9]+-[1-9][0-9]*$/,
  exampleReference: 'plane:SJUP-12',
  normalize(raw, invalid) {
    rejectFields(raw, ['team'], 'plane', invalid);
    return { provider: 'plane', project: requireString(raw, 'project', invalid) };
  },
};

const linear = {
  name: 'linear',
  fields: { required: ['team'], optional: ['project'] },
  referencePattern: /^linear:[A-Z][A-Z0-9]*-[1-9][0-9]*$/,
  exampleReference: 'linear:CEW-123',
  normalize(raw, invalid) {
    const team = requireString(raw, 'team', invalid);
    if (!TEAM_KEY.test(team)) {
      throw invalid('roadmap.team', 'must be an uppercase Linear team key such as CEW');
    }
    const roadmap = { provider: 'linear', team };
    if (raw.project !== undefined) {
      roadmap.project = requireString(raw, 'project', invalid);
    }
    return roadmap;
  },
};

const none = {
  name: 'none',
  normalize(raw, invalid) {
    rejectFields(raw, ['project', 'team'], 'none', invalid);
    return { provider: 'none' };
  },
};

export const ROADMAP_PROVIDERS = Object.freeze([file, plane, linear, none]);

export const EXTERNAL_ROADMAP_PROVIDERS = Object.freeze(
  ROADMAP_PROVIDERS.filter((provider) => provider.referencePattern !== undefined),
);

export const ROADMAP_KEYS = Object.freeze(['provider', 'project', 'team']);

export function roadmapProvider(name) {
  return ROADMAP_PROVIDERS.find((provider) => provider.name === name);
}
