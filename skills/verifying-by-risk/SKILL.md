---
name: verifying-by-risk
description: Use when implementation of a change stack is done and before handing it to finishing-a-change-stack, or when asked to grade, classify, or brief a pending stack for the operator
---

# Verifying by Risk

Scale verification to the risk of the whole pending stack, record what actually ran, and hand the operator a short brief instead of the whole diff.

**Announce at start:** "I'm using the verifying-by-risk skill to classify and verify this stack."

**Core principle:** A script decides the tier from paths and from policy on trunk. You may raise the tier, never lower it. The verdict records evidence for the operator. It is never a gate you can pass on your own authority.

`<this skill dir>` is the absolute directory holding the SKILL.md the harness loaded for this skill: take it from the skill's load path or its "base directory for this skill". Never search the filesystem for another copy of these scripts; a different checkout's scripts grade a different stack. If you cannot resolve the directory, stop and say so.

## Step 1: Classify

```bash
CLS=$(mktemp) && node <this skill dir>/scripts/classify-risk.mjs --repo "$(jj root)" > "$CLS"
```

`mktemp` gives a unique file outside the repository, whatever `TMPDIR` is. A file written inside the working copy gets snapshotted into `@` and changes the head you just classified. Read `$CLS` for the JSON, then `rm -f "$CLS"` when done.

The script resolves everything itself. Do not pass it a range or a policy file:

- **Trunk** is the local trunk bookmark from starting-a-change's `scripts/trunk-rev`, the same boundary finishing uses. Local `main` ahead of `main@origin` is fine (unpushed local landings). Local behind, diverged, or conflicted exits 2.
- **Head** is `@`, or `@-` when `@` is an empty single-parent change. An empty merge is the head itself.
- **Range** is `fork_point(trunk | head)..head`, which covers every pending change in the stack. `--range FROM..TO` is a cross-check only. Any other range exits 2. `tier`, `protected`, and `protectedPaths` come from the union of every path any commit in the range touched, source and target, merges included, so a protected path added and reverted later still counts: the intermediate commit is retained history. `paths` lists that union; `netPaths` is the net `fork_point..head` diff, for the brief only.
- **Policy** is `.sjujperpowers/risk.toml` as committed on trunk. A stack that edits `risk.toml` is still classified by trunk's copy. With no `risk.toml` on trunk, every change is `high`. A malformed one is also `high`, and `policy.error` says why.
- **Test command** is `risk.toml`'s `test` on trunk, reported as `testCommand`. You do not choose it.
- **Verify skill** is `verifySkill`: true when `.agents/skills/verify-*/SKILL.md` exists on trunk or at head. A stack that deletes trunk's verify skill gets no startup exception.
- **Protected paths** come from built-ins plus `risk.toml`'s `protected` list (see [hk-conventions.md](hk-conventions.md) for the built-ins). Any match sets `protected: true`, whatever the tier.

The JSON is for reading. `verdict.mjs` reclassifies on its own and never reads it. To raise the tier, pass `--raise medium|high` to both `classify-risk.mjs` and `verdict.mjs append`, and say why in the brief. Exit 2 means the stack cannot be classified (no trunk, trunk disagrees with origin, nothing pending, rejected range). Stop and report it; do not guess a tier.

## Step 2: Run the tier's evidence

| Tier | Evidence |
|---|---|
| low | `<this skill dir>/scripts/hk-check --evidence <path>` (the committed `hk.pkl`'s default steps) plus `testCommand` exactly as declared, with command receipts. The controller spot-checks them. |
| medium | everything for low, plus the affected features' verify recipes from the project's `verify-<project>` skill, with evidence paths |
| high | everything for medium, plus a verifier from a **different model family** than the implementer that runs the verify skill on the final change, plus a regression check against trunk. With no verify skill yet, the verifier and the recipes are unavailable and the startup exception below applies. |

- Run every command yourself, at the head the classification names. Record each run's command, exit status, and evidence path.
- **hk runs only through `scripts/hk-check`**, never bare `hk check`. hk also reads `hk.local.pkl`, `.config/hk.local.pkl`, `HK_*` variables, user config, and git config; none of those show up in a diff, and any of them can skip steps. `hk-check` pins the committed `hk.pkl`, clears the rest, and exits 2 if the repository's git config still skips or excludes anything. Its `--evidence` file lists the steps that ran and any override it ignored; link it from the brief.
- **Setup gaps** are never `blocked`; each stops the grade at what actually ran and gets an Attention note. There are exactly two: **no verify skill yet** — `classify-risk.mjs` reports `verifySkill: false` when neither trunk nor head has `.agents/skills/verify-*/SKILL.md`; record recipe evidence as unavailable, the grade stops at the highest level actually earned (at most `unit-tested`), a high-tier row needs no verifier, and Attention points to sjujperpowers:creating-a-verification-skill — and **no declared `test`** — no `test` in trunk's `risk.toml`, or no `risk.toml` on trunk; the grade stops at `type-check-only`, and Attention says to declare `test`. Missing required evidence that is not a setup gap (a verifier, verify recipes, the regression check, a passing run of a declared test when a verify skill exists) is `blocked`.
- **Different-family verifier:** dispatch it with the model selection your harness provides, giving it the verify skill path and the head commit. If the harness cannot select a model family different from the implementer's, the grade is `blocked`. Never substitute a same-family model. A different-family model that only reviewed the code is a code reviewer, not the verifier, because it did not run the required behavioral checks; record it with `--code-reviewer`.
- **Regression check against trunk:** run the same test commands on a checkout of the trunk outside the repository, then compare. `W=$(mktemp -d)/trunk; jj workspace add --quiet --name verify-trunk -r <policy.commit> "$W"`, run the commands in `$W`, then `jj workspace forget verify-trunk && rm -rf "$(dirname "$W")"`. Its working copy is a new empty change on top of the trunk, so the trunk itself is never edited.
- **Required commands** are `testCommand` and, when the head tracks an `hk.pkl`, `hk-check`. Record the hk run as `"command":"hk-check"`, never as its path: the ledger matches the command string exactly, and a path-form receipt counts as no hk run. For each required command, the latest `--run` of that exact command is its result, so a failure followed by a passing re-run counts as passing and a pass followed by a failure does not. Any required command whose latest run exits non-zero leaves `failed` as the only grade. When the head tracks an `hk.pkl`, every grade from `type-check-only` up also needs a passing `hk-check` run; without one the required evidence is missing, so the grade is `blocked`. Runs of other commands are exploratory and never constrain the grade.

**Grade** is the strongest one the evidence supports:

| Grade | Means |
|---|---|
| `failed` | a required check failed: the latest run of a required command exited non-zero |
| `blocked` | required evidence could not be produced, for any reason (for example, no different-family verifier, or a declared test with no passing run while a verify skill exists). Setup gaps are not `blocked`; see Step 2 |
| `type-check-only` | only static checks ran; the ceiling when no `test` is declared, or, with no verify skill, when the declared test has no passing run. No verify skill alone allows up to `unit-tested` |
| `unit-tested` | static checks and the declared `testCommand` passed |
| `behavior-tested` | plus verify recipes passed (needs a verify skill) |
| `live-verified` | plus a different-family verifier ran the verify skill on the final change (`--verifier-family` set and different from the implementer's, at every tier) |

## Step 3: Record the verdict

```bash
node <this skill dir>/scripts/verdict.mjs append \
  --repo "$(jj root)" \
  [--raise medium|high] \
  --grade <grade> \
  --implementer-family <family> \
  [--verifier-family <family>] \
  [--code-reviewer <family>]... \
  --run '{"command":"hk-check","exit":0,"evidence":"<hk-check evidence path>"}' \
  --run '{"command":"<testCommand>","exit":0,"evidence":"<path>"}'
```

`append` reclassifies the stack itself; it has no `--classification` input. The row records the computed tier, the effective (raised) tier, and the protected paths from that fresh classification.

The ledger is `.sjujperpowers/verdicts.jsonl`. On first use the script creates `.sjujperpowers/.gitignore` so that it and the ledger stay untracked. If `.sjujperpowers/.gitignore` already exists without a `/verdicts.jsonl` line, the script exits 2. Add the line, commit it as its own change, and append again.

`append` refuses:

- a `high` row graded above `blocked` unless the verifier family differs from the implementer's, when a verify skill exists. A code reviewer never satisfies this;
- `live-verified` at any tier unless `--verifier-family` is set and differs from the implementer's;
- `behavior-tested` or `live-verified` at any tier when there is no verify skill (`no verify skill: grade stops at unit-tested`);
- any grade but `failed` when the latest run of a required command exited non-zero;
- when the head tracks an `hk.pkl`, any grade from `type-check-only` up with no `hk-check` run (`blocked` fits);
- a grade of `unit-tested` or above unless a `--run` shows the declared `testCommand`, character for character, exiting 0. No `test` declared on trunk is a setup gap: the grade stops at `type-check-only`. A declared command with no passing run is missing evidence: `blocked` while a verify skill exists, otherwise still capped at `type-check-only`.

`check` runs the same consistency rules on the stored row, so a row edited after `append` (a raised grade, a dropped verifier or run, a changed `testCommand`, `verifySkill`, or `hkRequired`) is void.

Grade, runs, and model families are self-reported. The scripts check the tier, the protected paths, and the revisions, not whether a command really ran. The brief says so.

**A verdict is void** when the head's commit ID, the recorded `range.to`, the fork point, or the trunk has moved since the row was written (any rewrite, rebase, squash, or describe), when a fresh classification disagrees with the row (a stored tier below the recomputed one, or different `protected`/`protectedPaths`), or when the row contradicts itself. Check with:

```bash
node <this skill dir>/scripts/verdict.mjs check --repo "$(jj root)"
```

Exit 0 means current. Exit 1 means void or missing, so re-run Steps 1-3.

## Step 4: Write the operator brief

At most 40 lines, not counting links. Deeper evidence is linked, not pasted.

```markdown
## Why
<one or two sentences: the problem this stack solves>

## Scope
<what changed, by component; change IDs>

## Tradeoffs
<optional: choices the operator might have made differently>

## Blast radius
Tier <tier><, protected>. <who or what is affected if this is wrong>

## Verification
- <command> → exit <n> (<evidence path>)
- Grade: <grade>; verifier: <family or none>; code review: <families or none>
- Every run above is agent-run; there is no independent CI.
- Grade, runs, and model families are self-reported; tier and protected paths are script-checked.

## Attention
- Protected paths touched: <list, or none>
- Setup gaps: <no verify skill / no declared test, each with how to close it; or none>
- Read these hunks: <file:line ranges the operator should read, and why>
- Rulings: <link to the committed rulings file, and the count>
- Parked findings: <from SDD rulings, only those still needing a decision; or none>
- Not covered: <anything the evidence could not cover>
```

`verdict.mjs summary` prints the verdict lines for the Verification section.

## Hand-off

Give finishing-a-change-stack the brief and the verdict status. Finishing re-checks the verdict after any rebase. Before landing a protected stack it runs `classify-risk.mjs` again at the landing head and asks for explicit operator approval naming the protected paths from that fresh output, never from the ledger row or an earlier JSON.

## Red Flags

| Thought | Reality |
|---|---|
| "I'll pass `--range @-..@`, only the last change is new." | The range is the whole stack. The script rejects anything else. |
| "This stack relaxes `risk.toml`, so classify with the new rules." | Policy comes from trunk. A change never grades itself. |
| "`just test` is close enough to the declared command." | Run `testCommand` exactly. A substituted command is `blocked` while a verify skill exists; with no verify skill it is no passing run, so the grade is capped at `type-check-only`. |
| "I'll hand `append` the classification I already have." | It reclassifies. A file is never evidence. |
| "Same family, but a stronger model: good enough for high." | `blocked` (with a verify skill). The point is an independent failure mode. |
| "A different-family model reviewed the diff, so that's the verifier." | Code review is not the behavioral verifier. Record it with `--code-reviewer`. |
| "Tests passed before the rebase." | The verdict is void. Re-run. |
| "`hk check --all` is the same thing as `hk-check`." | Not with a local override or a skip in git config. Bare hk is not evidence. |
| "The brief should show the whole diff to be safe." | Link it. Attention names the hunks worth reading. |
| "I'll record `unit-tested`; the failing re-run was flaky." | The latest run of a required command decides. Re-run it to a pass, or record `failed`. |
| "`live-verified` is fine, the verifier is the same family at low tier." | `live-verified` needs a different-family verifier at every tier. |
