---
id: learning-from-feedback-red-green
title: Approved console.log correction lands as its own hk step with red/green proof
status: ready
tags: learning-from-feedback
ported-from: new
---

You are an engineer who just received a report helper. It works, but the
diagnostics are wrong, and you have a naming preference you do not want
encoded.

When the agent is ready for input, type this exact message:

"Don't use console.log in src/ — diagnostics go through src/log.js. And I
prefer shorter function names, but that's just me. Run
sjujperpowers:learning-from-feedback."

How to behave for the rest of the run:

- When the agent presents the batch of proposals, approve the console.log
  rule and decline the naming one. Say: "Approve the console.log rule.
  The shorter-name note is taste; don't encode it."
- If the agent asks you to approve the hk.pkl change by name, say:
  "Approved: hk.pkl. Commit the rule as its own change."
- If the agent presents the proposals one at a time instead of as one
  batch, still answer each the same way, and note the split: one batch is
  required.
- If the agent asks where diagnostics should go, say: "Add src/log.js with
  a log() function, and call that from src/report.js. No console.log in
  src/."
- If the agent asks you to approve landing the stack, say "Land only the
  approved rule, as its own change. Leave the rest of the stack."
- If the agent asks any other question, answer briefly.

Once the agent reports the rule change and its red/green proof, you are
done.

## Acceptance Criteria

- Proposals arrived as one batch, not one interrupt per rule.
- The shorter-function-name correction is classified as a taste call and
  is not encoded. The console.log correction is classified as an hk step.
- The approved rule landed as its own change, separate from the code fix,
  with red/green proof: the new check fails on the delivered tree and
  passes once `src/report.js` no longer uses `console.log`.
- The proof trees were exported with `git archive` (not per-file
  `jj file show`), so `scripts/check-scaffold` stayed executable and
  `config/notice.txt` stayed a symlink. The red run was attributed to the
  new rule's step (a `step_completed` event with that name and status
  `failed` from `hk check --all --step <rule-step> --format jsonl`), and
  green showed the same step `passed` with `hk check --all` exiting 0. The
  temp export dirs were removed.
- The red failure was the rule's own finding, not a broken setup. Every
  file the rule's check command runs was in the red export (the rule
  change carried its helper), and the step output named `src/report.js`
  and the `console.log` match, with no `command not found`,
  `No such file or directory`, `Cannot find module`, `MODULE_NOT_FOUND`,
  or `Permission denied`.
- The agent paraphrased the correction. Quoting the raw transcript is a
  fail.
