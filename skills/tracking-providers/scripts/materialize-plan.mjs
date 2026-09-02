#!/usr/bin/env node

import { execFile as execFileCallback } from 'node:child_process';
import { createHash } from 'node:crypto';
import { readFile } from 'node:fs/promises';
import { isAbsolute, relative, resolve, sep } from 'node:path';
import { fileURLToPath } from 'node:url';
import { promisify } from 'node:util';

import { resolveConfig } from './resolve-config.mjs';

const execFile = promisify(execFileCallback);

class CliUsageError extends Error {}

function requiredMatch(markdown, pattern, name) {
  const match = markdown.match(pattern);
  if (!match) throw new Error(`plan is missing ${name}`);
  return match;
}

function assertTasks(tasks) {
  if (tasks.length === 0) throw new Error('plan must contain at least one Task heading');
  for (let index = 0; index < tasks.length; index += 1) {
    if (tasks[index].number !== index + 1) {
      throw new Error('task numbers must be exactly 1, 2, ...');
    }
  }
}

function withoutFencedCode(markdown) {
  let fence = null;
  return markdown
    .split('\n')
    .map((line) => {
      const marker = line.match(/^\s{0,3}(`{3,}|~{3,})/);
      if (fence === null) {
        if (marker === null) return line;
        fence = { character: marker[1][0], length: marker[1].length };
        return '';
      }

      const closingMarker = line.match(/^\s{0,3}(`{3,}|~{3,})\s*$/);
      if (
        closingMarker !== null
        && closingMarker[1][0] === fence.character
        && closingMarker[1].length >= fence.length
      ) {
        fence = null;
      }
      return '';
    })
    .join('\n');
}

export function parsePlan(markdown) {
  const structuralMarkdown = withoutFencedCode(markdown);
  const title = requiredMatch(
    structuralMarkdown,
    /^# (.+) Implementation Plan$/m,
    'implementation-plan title',
  )[1].trim();
  const spec = requiredMatch(
    structuralMarkdown,
    /^\*\*Spec:\*\* `([^`]+)`$/m,
    'Spec header',
  )[1];
  const source = requiredMatch(
    structuralMarkdown,
    /^\*\*Source:\*\* (.+)$/m,
    'Source header',
  )[1].trim();
  const tasks = [...structuralMarkdown.matchAll(/^### Task (\d+): (.+)$/gm)].map(
    (match) => ({
      number: Number(match[1]),
      title: match[2].trim(),
    }),
  );
  assertTasks(tasks);
  return { title, spec, source, tasks };
}

function planRelativePath(root, planPath) {
  const path = relative(resolve(root), resolve(planPath));
  if (path === '' || path === '..' || path.startsWith(`..${sep}`) || isAbsolute(path)) {
    throw new Error('plan must be inside repository root');
  }
  return path;
}

function keyPrefix(project, relativePlan) {
  const digest = createHash('sha256')
    .update(`${project}\0${relativePlan}`)
    .digest('hex')
    .slice(0, 24);
  return `sjujperpowers:${digest}`;
}

function metadataArgs(metadata) {
  return Object.entries(metadata).flatMap(([key, value]) => [
    '--meta',
    `${key}=${value}`,
  ]);
}

function normalizeCreatedIssue(payload, project) {
  const shortId = payload?.issue?.short_id;
  if (typeof shortId !== 'string' || shortId === '') {
    throw new Error('Kata create response is missing issue.short_id');
  }
  return {
    ref: `${project}#${shortId}`,
    created: payload.reused !== true && payload.changed !== false,
  };
}

async function defaultRunKata(args, root) {
  const { stdout } = await execFile('kata', args, {
    cwd: root,
    encoding: 'utf8',
    maxBuffer: 1024 * 1024,
  });
  try {
    return JSON.parse(stdout);
  } catch (error) {
    throw new Error(`Kata returned invalid JSON: ${error.message}`);
  }
}

function createArgs(project, title, body, key, metadata, parent = null) {
  const args = [
    '--project',
    project,
    '--json',
    'create',
    title,
    '--body',
    body,
    '--idempotency-key',
    key,
    ...metadataArgs(metadata),
  ];
  if (parent === null) {
    args.push('--label', 'sjujperpowers-plan');
  } else {
    args.push(
      '--label',
      'sjujperpowers-task',
      '--parent',
      parent,
      '--blocks',
      parent,
    );
  }
  return args;
}

export async function materializePlan({
  root,
  planPath,
  markdown,
  config,
  runKata = (args) => defaultRunKata(args, root),
}) {
  if (config.execution.provider !== 'kata') {
    throw new Error('execution.provider must be kata to materialize a plan');
  }

  const relativePlan = planRelativePath(root, planPath);
  const parsed = parsePlan(markdown);
  const project = config.execution.project;
  const prefix = keyPrefix(project, relativePlan);
  const metadata = {
    'sjujperpowers.plan': relativePlan,
    'sjujperpowers.spec': parsed.spec,
    'sjujperpowers.source': parsed.source,
  };
  const partial = { parent: null, children: [] };

  try {
    const parentPayload = await runKata(
      createArgs(
        project,
        parsed.title,
        `Source: ${parsed.source}\nSpec: ${parsed.spec}\nPlan: ${relativePlan}`,
        `${prefix}:parent`,
        metadata,
      ),
    );
    partial.parent = normalizeCreatedIssue(parentPayload, project);
  } catch (error) {
    error.partial = partial;
    throw error;
  }

  const parentShortId = partial.parent.ref.slice(project.length + 1);
  for (const task of parsed.tasks) {
    try {
      const payload = await runKata(
        createArgs(
          project,
          `Task ${task.number}: ${task.title}`,
          `Requirements: ${relativePlan} — Task ${task.number}: ${task.title}`,
          `${prefix}:task:${task.number}`,
          { ...metadata, 'sjujperpowers.task': String(task.number) },
          parentShortId,
        ),
      );
      partial.children.push({
        task: task.number,
        ...normalizeCreatedIssue(payload, project),
      });
    } catch (error) {
      const wrapped = new Error(`Kata materialization failed at Task ${task.number}: ${error.message}`);
      wrapped.partial = partial;
      throw wrapped;
    }
  }

  return partial;
}

function parseArgs(args) {
  let root = process.cwd();
  let planPath = null;
  for (let index = 0; index < args.length; index += 1) {
    const arg = args[index];
    const value = args[index + 1];
    if (arg === '--root') {
      if (!value) throw new CliUsageError('--root requires a directory');
      root = resolve(value);
      index += 1;
    } else if (arg === '--plan') {
      if (!value) throw new CliUsageError('--plan requires a path');
      planPath = value;
      index += 1;
    } else {
      throw new CliUsageError(`unknown argument: ${arg}`);
    }
  }
  if (planPath === null) throw new CliUsageError('--plan is required');
  return {
    root,
    planPath: resolve(root, planPath),
  };
}

async function main() {
  try {
    const { root, planPath } = parseArgs(process.argv.slice(2));
    const config = await resolveConfig(root);
    const markdown = await readFile(planPath, 'utf8');
    const result = await materializePlan({ root, planPath, markdown, config });
    process.stdout.write(`${JSON.stringify(result)}\n`);
  } catch (error) {
    const output = error.partial
      ? JSON.stringify({ error: error.message, partial: error.partial })
      : error.message;
    process.stderr.write(`${output}\n`);
    process.exitCode = error instanceof CliUsageError ? 2 : 1;
  }
}

if (process.argv[1] && fileURLToPath(import.meta.url) === resolve(process.argv[1])) {
  await main();
}
