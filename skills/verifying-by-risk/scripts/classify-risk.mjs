#!/usr/bin/env node
import { flag, repoArg, snapshot } from './jj.mjs';
import { classify } from './classify.mjs';

const argv = process.argv.slice(2);
const repo = repoArg(argv);
snapshot(repo);
const result = classify(repo, {
  head: flag(argv, '--head'),
  range: flag(argv, '--range'),
  raise: flag(argv, '--raise'),
});
process.stdout.write(`${JSON.stringify(result)}\n`);
