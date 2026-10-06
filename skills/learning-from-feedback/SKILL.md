---
name: learning-from-feedback
description: Use when the operator corrects delivered work in a session ("don't do X", "we always Y", "that's wrong because"), or asks to mine a repository's past agent sessions for corrections that should become rules
---

# Learning from Feedback

Turn each operator correction into the strongest durable check that would have caught it, so the same correction is never needed twice.

**Announce at start:** "I'm using the learning-from-feedback skill to turn this correction into a check."

**Core principle:** A correction that only lives in this conversation is lost at the next session. One that lives in a check fails the next agent's build.

## Modes

- **Live:** the operator corrects delivered work in this session. Handle the corrections after the immediate fix is made and confirmed.
- **Seeding:** the operator asks you to mine a repository's session history, for example OMP's `~/.omp/agent/sessions/<project-dir>/*.jsonl`. Read only the user turns: `jq -r 'select(.type == "message" and .message.role == "user") | .message.content[]? | select(.type == "text") | .text' <session>.jsonl`. Work through them in your own context. Never write transcript text to a file, a commit, or a tracker.

## For each correction

1. **Paraphrase it.** Record the correction and its context in your own words. Never copy raw transcript text: it may contain credentials, hostnames, or private details.
2. **Classify it** at the strongest feasible layer, in this order:

   | Layer | Example |
   |---|---|
   | structure or types | a newtype, an enum, an API that makes the mistake unrepresentable |
   | hard check as an hk step | lint config, ast-grep rule, grep script, tool flag (see verifying-by-risk's [hk-conventions.md](../verifying-by-risk/hk-conventions.md)) |
   | regression test or verify-recipe entry | a test that fails on the corrected behavior |
   | Sjujperpowers workflow change | the agent skipped or misread a skill step; a process failure |
   | AGENTS.md note | last resort: true, but no tool can check it |
   | taste call, stays with the operator | a preference with no right answer; record nothing |

   Pick the first layer that can actually catch it. "Stays with the operator" is a real outcome, not a failure.
3. **Scope it:**
   - **this repository:** the rule lands here.
   - **the project's template:** when the rule belongs in the template the project was generated from, hand the proposal to the operator instead of editing the template.
   - **Sjujperpowers:** restate it generically, without project names, paths, or details, before it leaves a private project.

## Present one batch

Collect every proposal, then ask once:

```
Proposed rules from this session's corrections:

1. <paraphrase> → <layer>, <scope>: <the concrete check>
2. <paraphrase> → taste call, stays with you. Nothing recorded.

Approve, edit, or reject each by number.
```

Do not interrupt the operator per rule, and do not land anything before the batch is answered.

## Land each approved rule

Each approved rule is **its own change**, separate from any code fix:

1. **Red:** run the check against the corrected version, the revision before the fix. It must fail, and the failure must come from the new rule's step. Export that revision's tree outside the repository, overlay only the new check files from the fixed working copy, and give the export a Git repository, because hk needs one. The rule change carries every file its check command runs: a helper left in the fix commit is missing from this export.

   Export with `git archive`, the one git command this skill uses: `jj file show` writes every file as a plain non-executable file, so executable helpers and symlinks would be lost and the proof would fail or pass for the wrong reason. `jj git root` makes the command work in non-colocated repositories too.

   `<verifying-by-risk skill dir>` is the directory of the verifying-by-risk skill as the harness loaded it, not a copy found by searching the filesystem. If you cannot resolve it, stop and say so.

   ```bash
   GITDIR=$(jj git root)
   FIXED=$(jj log -r @ --no-graph -T commit_id)    # the working copy, holding the new check
   CORRECTED=$(jj log -r <corrected-rev> --no-graph -T commit_id)
   W=$(mktemp -d)
   git --git-dir="$GITDIR" archive "$CORRECTED" | tar -x -C "$W"
   git --git-dir="$GITDIR" archive "$FIXED" hk.pkl | tar -x -C "$W"    # and each other new check file, at the same path
   jj git init --colocate "$W" >/dev/null 2>&1
   (cd "$W" && <verifying-by-risk skill dir>/scripts/hk-check --step <rule-step> --format jsonl 2>/dev/null \
     | jq -r 'select(.event == "run_completed") | .data | "failure: \(.failure)", (.steps[] | "\(.name) \(.status):", (.output // ""))')
   rm -rf "$W"
   ```

   Read the output, not just the status. Require all of these:

   - the `<rule-step> failed:` line is present. No output means the step never ran: `hk check --step NAME` exits 0 when NAME matches no step, so the exit status alone proves nothing. A different failing step is not red for this rule;
   - every path in the `failure:` command that exists in the fixed tree also exists in the export, so a missing helper is caught;
   - the output names the violation you predicted before running, the offending file and match. A learned rule's check must print what it found, for example `grep -Hn` rather than `grep -q`;
   - the output has no startup-failure marker: `command not found`, `No such file or directory`, `Cannot find module`, `MODULE_NOT_FOUND`, `Permission denied`, or `ModuleNotFoundError`. Node exits 1 on a missing module, so exit 1 does not prove the assertion ran.
2. **Green:** export the fixed working copy the same way into a fresh `W=$(mktemp -d)` with `git --git-dir="$GITDIR" archive "$FIXED" | tar -x -C "$W"`, run `jj git init --colocate "$W"`, and run there, then `rm -rf "$W"`:

   - the same `hk-check --step <rule-step> --format jsonl` pipeline must print `<rule-step> passed:`;
   - `hk-check` must exit 0.

   Run hk only through `hk-check`: a git-ignored `hk.local.pkl` or an `HK_SKIP_STEPS` in your environment would otherwise change what red and green prove.

   Never run green in the working copy. The export drops anything untracked-by-accident and exposes a lost executable bit or symlink that the working copy hides.
3. **Commit by fileset:** `jj commit <check files> -m "<rule>"`. A rule that touches a protected path (`hk.pkl`, `.hk/**`, and the others listed in hk-conventions.md) is not committed until the operator's approval names that path: approving the rule is not approving the path. Ask for the path by name and leave the rule uncommitted until then.
4. Report the red and green commands with their exit statuses and the step status each printed.

A rule that passes on the corrected version catches nothing. Fix the rule, not the proof.

## Red Flags

| Thought | Reality |
|---|---|
| "I'll add a line to AGENTS.md; quicker than a check." | Last resort. Try every stronger layer first. |
| "I'll quote the operator's message so the rule is exact." | Paraphrase. Transcripts can carry secrets. |
| "I'll fold the rule into the fix commit." | Its own change, so it can be reviewed and reverted alone. |
| "Ask about each rule as it comes up." | One batch. |
| "Every correction needs a rule." | Taste calls stay with the operator. |
| "They approved the rule, so hk.pkl is approved." | Approval names the path. Until it does, the rule stays uncommitted. |
