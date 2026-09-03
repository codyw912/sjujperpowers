#!/usr/bin/env node

import { execFile as execFileCallback, spawnSync } from 'node:child_process';
import { realpathSync } from 'node:fs';
import { readFile } from 'node:fs/promises';
import { isAbsolute, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { promisify } from 'node:util';

const execFile = promisify(execFileCallback);
const DEFAULT_DOCS_ROOT = 'docs/project';

const DEFAULT_CONFIG = Object.freeze({
  version: 1,
  configPath: null,
  docsRoot: DEFAULT_DOCS_ROOT,
  roadmap: Object.freeze({ provider: 'file' }),
  execution: Object.freeze({ provider: 'session', completion: 'landed' }),
});

class CliUsageError extends Error {}

function invalid(configPath, field, message) {
  return new Error(`${configPath}: ${field} ${message}`);
}

function isObject(value) {
  return value !== null && typeof value === 'object' && !Array.isArray(value);
}

function rejectUnknownKeys(value, allowed, configPath, prefix) {
  for (const key of Object.keys(value)) {
    if (!allowed.includes(key)) {
      throw invalid(configPath, `${prefix}.${key}`, 'is not supported');
    }
  }
}

function requireProject(value, configPath, field) {
  if (typeof value !== 'string' || value.trim() === '') {
    throw invalid(configPath, field, 'must be a non-empty string');
  }
  return value.trim();
}

function normalizeDocsRoot(raw, configPath) {
  if (raw === undefined) return DEFAULT_DOCS_ROOT;
  if (typeof raw !== 'string' || raw.trim() === '') {
    throw invalid(configPath, 'docsRoot', 'must be a non-empty string');
  }

  const docsRoot = raw.trim().replace(/\/+$/, '');
  if (
    docsRoot === '' ||
    isAbsolute(docsRoot) ||
    docsRoot.includes('\\') ||
    docsRoot.split('/').some(segment => segment === '' || segment === '.' || segment === '..')
  ) {
    throw invalid(
      configPath,
      'docsRoot',
      'must be a repository-relative directory without empty, . or .. segments',
    );
  }
  return docsRoot;
}

function normalizeRoadmap(raw, configPath) {
  if (raw === undefined) return { provider: 'file' };
  if (!isObject(raw)) throw invalid(configPath, 'roadmap', 'must be an object');
  rejectUnknownKeys(raw, ['provider', 'project'], configPath, 'roadmap');

  const provider = raw.provider;
  if (!['file', 'plane', 'none'].includes(provider)) {
    throw invalid(configPath, 'roadmap.provider', 'must be one of: file, plane, none');
  }

  if (provider === 'plane') {
    return {
      provider,
      project: requireProject(raw.project, configPath, 'roadmap.project'),
    };
  }
  if (raw.project !== undefined) {
    throw invalid(configPath, 'roadmap.project', `is not valid for provider ${provider}`);
  }
  return { provider };
}

function normalizeExecution(raw, configPath) {
  if (raw === undefined) return { provider: 'session', completion: 'landed' };
  if (!isObject(raw)) throw invalid(configPath, 'execution', 'must be an object');
  rejectUnknownKeys(raw, ['provider', 'project', 'completion'], configPath, 'execution');

  const provider = raw.provider;
  if (!['session', 'kata', 'none'].includes(provider)) {
    throw invalid(configPath, 'execution.provider', 'must be one of: session, kata, none');
  }

  const completion = raw.completion ?? 'landed';
  if (!['landed', 'pull_request'].includes(completion)) {
    throw invalid(configPath, 'execution.completion', 'must be one of: landed, pull_request');
  }

  if (provider === 'kata') {
    return {
      provider,
      project: requireProject(raw.project, configPath, 'execution.project'),
      completion,
    };
  }
  if (raw.project !== undefined) {
    throw invalid(configPath, 'execution.project', `is not valid for provider ${provider}`);
  }
  return { provider, completion };
}

export function normalizeConfig(raw, configPath) {
  if (!isObject(raw)) throw invalid(configPath, 'root', 'must be an object');
  rejectUnknownKeys(raw, ['version', 'docsRoot', 'roadmap', 'execution'], configPath, 'root');
  if (raw.version !== 1) throw invalid(configPath, 'version', 'must equal 1');

  return {
    version: 1,
    configPath,
    docsRoot: normalizeDocsRoot(raw.docsRoot, configPath),
    roadmap: normalizeRoadmap(raw.roadmap, configPath),
    execution: normalizeExecution(raw.execution, configPath),
  };
}

function defaultCommandExists(command) {
  const result = spawnSync(command, ['version'], { stdio: 'ignore' });
  return result.error?.code !== 'ENOENT';
}

async function defaultRunCommand(command, args) {
  return execFile(command, args, {
    encoding: 'utf8',
    maxBuffer: 1024 * 1024,
  });
}

export async function preflightKata(
  project,
  {
    commandExists = defaultCommandExists,
    runCommand = defaultRunCommand,
    configPath = '.sjujperpowers/config.json',
  } = {},
) {
  if (!commandExists('kata')) {
    throw invalid(
      configPath,
      'execution.provider',
      'selects kata but the kata executable is unavailable',
    );
  }

  try {
    await runCommand('kata', ['health', '--json']);
  } catch (error) {
    throw invalid(
      configPath,
      'execution.provider',
      `cannot reach the kata daemon: ${error.message}`,
    );
  }

  try {
    await runCommand('kata', ['projects', 'show', project, '--json']);
  } catch (error) {
    throw invalid(
      configPath,
      'execution.project',
      `kata project ${JSON.stringify(project)} is unavailable: ${error.message}`,
    );
  }
}

export async function resolveConfig(root, options = {}) {
  const configPath = resolve(root, '.sjujperpowers/config.json');
  let text;
  try {
    text = await readFile(configPath, 'utf8');
  } catch (error) {
    if (error.code === 'ENOENT') return structuredClone(DEFAULT_CONFIG);
    throw error;
  }

  let raw;
  try {
    raw = JSON.parse(text);
  } catch (error) {
    throw new Error(`${configPath}: invalid JSON: ${error.message}`);
  }

  const config = normalizeConfig(raw, configPath);
  if (options.runtimeCheck !== false && config.execution.provider === 'kata') {
    await preflightKata(config.execution.project, {
      commandExists: options.commandExists ?? defaultCommandExists,
      runCommand: options.runCommand ?? defaultRunCommand,
      configPath,
    });
  }
  return config;
}

function parseArgs(args) {
  let root = process.cwd();
  let runtimeCheck = true;

  for (let index = 0; index < args.length; index += 1) {
    const arg = args[index];
    if (arg === '--root') {
      const value = args[index + 1];
      if (!value) throw new CliUsageError('--root requires a directory');
      root = resolve(value);
      index += 1;
    } else if (arg === '--no-runtime-check') {
      runtimeCheck = false;
    } else {
      throw new CliUsageError(`unknown argument: ${arg}`);
    }
  }
  return { root, runtimeCheck };
}

async function main() {
  try {
    const { root, runtimeCheck } = parseArgs(process.argv.slice(2));
    const config = await resolveConfig(root, { runtimeCheck });
    process.stdout.write(`${JSON.stringify(config)}\n`);
  } catch (error) {
    process.stderr.write(`${error.message}\n`);
    process.exitCode = error instanceof CliUsageError ? 2 : 1;
  }
}

if (process.argv[1] && fileURLToPath(import.meta.url) === realpathSync(resolve(process.argv[1]))) {
  await main();
}
