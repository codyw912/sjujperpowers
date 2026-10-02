# Verification and Feedback Loop Pilot Design

**Outcome:** plane:SJUP-2

Source brief: the "PILOT BRIEF" comment on SJUP-2, as corrected by later comments in that thread and by the operator's rulings recorded below.

## Summary

Sjujperpowers gains three general skills: one turns operator corrections into durable checks, one generates a project verification skill, and one scales verification to risk and writes a short operator brief. Projects get generated, project-specific artifacts. Bloomery is the first consumer and the proof. The operator reads the brief and any flagged hunks instead of the whole diff, and keeps final say on landing and on every rule change.

Sjujperpowers is public, so it contains no Bloomery material. Eval fixtures are synthetic. Workflow-rule proposals mined from Bloomery sessions are paraphrased without project details before they reach Sjujperpowers.

## Decisions (operator-approved 2026-09-30)

| # | Decision |
|---|---|
| D1 | Project verify skills live in `.agents/skills/verify-<project>/`, with a `.claude/skills/verify-<project>` symlink for Claude Code. OMP dedupes by name and realpath, so the symlink does not load the skill twice. |
| D2 | No new devenv input. The nix-config Rust template carries `nix/hk.nix` and `scripts/update-hk`, described under nix-config below. Projects copy both and import `nix/hk.nix` from `devenv.nix`. Upgrading means running `scripts/update-hk` and committing the result, not `devenv update`. The Rust hk base is copied into each project as `.hk/base/rust.pkl`. A shared base is deferred until a second project consumes it. Bloomery therefore has no private nix-config input, and hk binaries come from public GitHub releases. Because `nix/hk.nix` and `scripts/update-hk` are protected, every hk upgrade needs operator approval in each repository; that is accepted. |
| D3 | hk replaces git-hooks.nix in the Rust template and in Bloomery, including the `git-hooks` input in `devenv.yaml`, so each project has one check configuration. |
| D4 | Verdicts in flight go to `.sjujperpowers/verdicts.jsonl`, which gets its own ignore entry. The durable record is the Kata completion comment, or the PR body when completion is `pull_request`. Finishing re-checks that the verdict's commit ID is the commit that lands. A rebase onto a moved trunk voids the verdict, so verification re-runs after the final rebase. |
| D5 | The end-to-end proof is configurable bounds for Bloomery's model-silence watchdog, a follow-up to #37, which hardcoded 60 s and 10 min. Bloomery's `risk.toml` lands on `main` before this change is classified, so the rules cannot be tuned to the proof. |
| D6 | Execution is tracked in the Kata projects `sjujperpowers` and `bloomery`. Both exist on the agent-workstation daemon. |
| D7 | nix-config work happens in a fresh clone on agent-workstation, as a new change on `devenv-cutover`, and is not pushed. The operator confirms GitHub `devenv-cutover` matches the laptop before work starts. |
| D8 | **Pilot scope:** GitHub Actions is out of scope for this pilot. "CI" means the `hk check --all` run at finishing. This narrows the brief's "Done when". It is a scope choice, not a blocker: after D2 Bloomery has no private inputs, so a later workflow needs no extra credential. The brief's Verification section says every run was agent-run. |
| D9 | One new skill, `verifying-by-risk`, owns risk classification, the verdict ledger, and the operator brief. Existing skills only call into it. |
| D10 | The changed-path range and the policy source are resolved separately, and neither comes from the change. The range always covers the whole pending stack. Policy is loaded from the trusted trunk, the local `main` bookmark. `verifying-by-risk` checks the diff against the protected-path list **in code**. Any change that touches a protected path needs explicit operator approval to land, whatever its tier. |
| D11 | Candidate skills reach Bloomery without a homelab pin bump. Bloomery's `.omp/config.yml` points `skills.customDirectories` at `skills/` inside a dedicated Sjujperpowers jj workspace at the candidate revision, never the main checkout. This was tested on OMP 18.4.4: it loads new skills and overrides same-name skills from the pinned plugin; `--plugin-dir` did not work. `.omp/config.yml` goes in Bloomery's `.git/info/exclude`. This covers skills only: if the work needs a change to `.omp/extensions/` or `.pi/extensions/`, stop and raise a decision. |
| D12 | **Plan review (2026-10-01).** (a) `devenv.nix` and `.agents/skills/verify-*/{SKILL.md,features/**}` are built-in protected paths. (b) The unit-test command is `risk.toml`'s `test` on trunk; a grade of `unit-tested` or above needs a passing run of exactly that command. (c) Every test removes its temp repos. (d) One trunk resolver, `trunk-rev`, returns the local trunk bookmark for both finishing and classification; it stops when local trunk is behind, diverged from, or conflicted with `<name>@origin`. `starting-a-change`'s `fresh-change` bases new work on that bookmark and stops on the same disagreements, and on a stack forked from an older trunk. Review bases with no recorded commit (SDD final review, the requesting-code-review fallback) are `trunk-rev --fork-point @`, never the trunk commit itself. Finishing's test step runs the policy-declared `testCommand`, reusing a passing receipt only at the verdict's head. Manual eval runs end with `evals/run teardown`. (e) `verdict.mjs append` reclassifies instead of reading a classification file and records computed and effective tiers. `check` reclassifies; it voids a row whose tier is below the recomputed tier or whose `protected`/`protectedPaths` differ. Finishing takes protected-path approval from a fresh classification at the landing head. Grade, runs, and model families are self-reported, and the brief says so. (f) The learning-from-feedback red proof exports revisions with `git archive`, so exec bits and symlinks survive, and asserts the failure comes from the new rule's step. |
| D13 | **Spec review (2026-10-01).** (a) hk reads configuration no diff shows: `hk.local.pkl` and `.config/hk.local.pkl` (usually git-ignored) win over `hk.pkl`, and `skip_steps`, `skip_hooks`, and `exclude` merge from `HK_*` variables, git config, and user config. Every hk run in verification, red/green proof, and finishing goes through `verifying-by-risk`'s `scripts/hk-check`, which pins `HK_FILE` to the root `hk.pkl`, clears `HK_*`, uses an empty user config directory, hides `~/.gitconfig` and system git config, refuses (naming the source) when the effective configuration still skips steps, skips hooks, or excludes files (repository and `$XDG_CONFIG_HOME` git config; `hk.skipHooks=check` exits 0 with every step still listed as included in the plan), and writes the plan (steps run and skipped, overrides ignored) as evidence. (b) Local trunk stays the policy source; see Limitations. (c) `.config/hk.pkl` and `.claude/skills/verify-*` are built-in protected paths. Projects protect whatever their declared checks read; Bloomery's `risk.toml` protects `justfile`, `clippy.toml`, `rustfmt.toml`, `.cargo/config.toml`, `rust-toolchain.toml`, `deny.toml`, and `Cargo.toml` (it declares `[lints]`) where they exist. |
| D14 | **Operator ruling on grades (2026-10-01).** (a) A grade is `blocked` whenever required evidence could not be produced, for any reason, and `failed` when a check failed. (b) There are exactly two setup gaps, each stopping the grade at what actually ran (never `blocked`) with an Attention note: **no verify skill yet** — recipe evidence is unavailable, the grade stops at the highest level earned (at most `unit-tested`), a high-tier row needs no verifier, and Attention points to creating-a-verification-skill; and **no declared `test`** — no `test` in trunk's `risk.toml`, or no `risk.toml` — the grade stops at `type-check-only`, whether or not a verify skill exists. `classify-risk.mjs` reports `verifySkill`, true when `.agents/skills/verify-*/SKILL.md` exists on trunk or at head, so a stack that deletes trunk's verify skill gets no exception and a stack that adds one has a skill to run. `blocked` remains for missing required evidence: no different-family verifier when a verify skill exists, verify recipes not run, the regression check skipped, or a declared `testCommand` with no passing run of exactly it while a verify skill exists; a failed run of the declared command is `failed`. (c) A different-family model that only reviewed code is a code reviewer, not the behavioral verifier, because it did not run the required behavioral checks. `append --code-reviewer <family>` records it as `codeReviewers` and never satisfies the verifier requirement. 2026-10-02: the operator reversed the earlier reading that a missing test declaration is `blocked`; it is a setup gap, keeping D12(b) intact. |
| D15 | **Independent review of PR #1 (2026-10-02).** (a) `live-verified` needs a different-family verifier at every tier, not only high. (b) Required commands are the declared `testCommand`, plus `hk-check` when the head tracks `hk.pkl`, recorded as the literal command string `hk-check`, not its path. The latest `--run` of each required command is its result: a later failure overrides an earlier pass, and only `failed` fits. A missing `testCommand` receipt is missing evidence (`blocked`) when a verify skill exists. Without a verify skill, D14's setup gap still applies, and the grade is capped at `type-check-only`. A missing `hk-check` receipt with `hk.pkl` tracked is `blocked` at every grade from `type-check-only` up, whether or not a verify skill exists. Runs of other commands never constrain the grade. (c) `append` and `check` share one consistency validator. `check` also voids a row whose `range.to` is not the head, or whose `testCommand`, `verifySkill`, or `hkRequired` no longer matches a fresh derivation. Every row written before this change lacks `hkRequired` and is void, accepted for the pilot: re-append at the current head. (d) Tier and protection come from the union of paths touched by every commit in the range; the net diff is reported separately as `netPaths`. A path touched and then reverted, or renamed away and back, still counts. (e) The head skips an empty `@` only when `@` has one parent; an empty merge is the head. (f) `hk-check` refuses `--plan`, `-P`, `--why`, and `-W`, so a plan-only run is never a receipt. (g) learning-from-feedback RED needs every helper the rule's check references to be present in the RED export, the step's output to show the stated violation, and no startup-failure marker (missing command or module, permission denied, exit 126/127). (h) The tally eval asserts the captured adds and a `total=N` equal to their sum; a capture-only driver is a negative case. |

Ordering: the nix-config plan, then the Sjujperpowers plan, then the Bloomery plan. Bloomery copies `nix/hk.nix` and the base directly, so it does not wait on a nix-config push.

## Preconditions

- Bloomery work in flight is not the base. Before the Bloomery plan starts, the operator lands all of it and leaves a fresh empty change to implement on.
- Before the nix-config plan starts, the operator confirms D7.

## Sjujperpowers: general components

### `learning-from-feedback` (new skill)

Triggers:

- live mode: the operator corrects delivered work in a session;
- seeding mode: the operator asks to mine a repository's OMP session history.

For each correction:

1. **Paraphrase it.** Record the correction and its context in the agent's own words. Never copy raw transcript text; it may contain credentials.
2. **Classify it** at the strongest feasible layer, in this order:
   - structure or types;
   - a hard check run as an hk step (lint, ast-grep rule, script, tool config);
   - a regression test or verify-recipe entry;
   - a Sjujperpowers workflow change, when it was a process failure;
   - an AGENTS.md note, as a last resort;
   - "taste call, stays with the operator".
3. **Scope it** to this repository, the nix-config template, or Sjujperpowers.
   - D2 has no shared base yet, so template-scoped proposals are handed to the operator.
   - A Sjujperpowers proposal from a private project is restated generically, without project names, paths, or details.
4. **Batch the proposals** into one approval request; do not interrupt per rule.
5. **Land each approved rule as its own change** with red/green proof: the check fails on the corrected version and passes on the fix. Each revision is exported with `git archive <commit> | tar -x`, so exec bits and symlinks survive, and the red failure must come from the new rule's own hk step (its `step_completed` event), not from any failing step. Rules that touch protected paths follow D10.

### `creating-a-verification-skill` (new skill)

Adapted from pstack `create-verification-skill` without Cursor mechanics. Generated layout:

```
.agents/skills/verify-<project>/
  SKILL.md        # Launch, Doctor, Drive, Evidence, Cleanup, Helpers
  features/<feature>.md   # entry points, preconditions, steps paired with observable results, gotchas
  scripts/        # rerunnable launch/doctor/drive/cleanup; preferred over prose
.claude/skills/verify-<project> -> ../../.agents/skills/verify-<project>
```

Sjujperpowers ships reusable drivers that generated scripts call. The first is a tmux TTY driver, for CLI/TUI projects; a browser driver is out of scope. Generation is not done until launch → doctor → one feature → evidence → cleanup has run end to end and the evidence path is reported. Maintenance mode is a follow-up.

### `verifying-by-risk` (new skill)

**Diff range and policy source (D10)** are resolved independently:

- **Trunk** is the local trunk bookmark from `starting-a-change`'s `trunk-rev`, the same boundary finishing uses (D12d). Local landings move it and nothing pushes it, so a remote bookmark is never the boundary. Local ahead of `<name>@origin` is fine; behind, diverged, or conflicted stops classification.
- **Diff range:** the script takes the head revision and computes the range itself: from the fork point of trunk and head, to head. That covers every pending change in `trunk..head`.
  - A caller may pass a range only as a cross-check. Any range that differs from the computed one is rejected with an error. That includes ranges starting at `@-`, at a mid-stack change, or anywhere off trunk.
- **Policy source:** `risk.toml` and the project's protected paths are loaded from the commit trunk points to at classification time. They are never loaded from the range's endpoints or from the change under test.

**Inputs, loaded from the policy commit:**

- `.sjujperpowers/risk.toml`: ordered path-glob rules mapping to `low`, `medium`, or `high`, a default tier, the project's unit-test command (`test`), and project-specific protected paths. **If the policy commit has no `risk.toml`, every change is `high`.**
- Built-in protected paths, which apply whether or not `risk.toml` exists:
  - `hk.pkl`, `.config/hk.pkl`, `.hk/**`, `nix/hk.nix`, `scripts/update-hk`
  - `.sjujperpowers/risk.toml`
  - `.agents/skills/verify-*/SKILL.md`, `.agents/skills/verify-*/features/**`, `.agents/skills/verify-*/scripts/**`, `.claude/skills/verify-*` (retargeting the link swaps the verify skill)
  - `.github/workflows/**`
  - `devenv.nix`, `devenv.yaml`, `devenv.lock`
- Built-ins cover hk's own configuration, not everything the checks read. Each project's `risk.toml` protects the files its declared checks and `test` command read (`justfile` recipes they call, linter, formatter, and toolchain config). `creating-a-verification-skill` lists the files its recipes read, and hk-conventions states the rule (D13c).

**Classification** is a script, not model judgment:

- It lists the paths touched by every commit in the computed range, from one `jj log` template over `fork_point..head`, so a path touched and later reverted still counts (D15d). Both sides of a rename count. The net endpoint diff is reported separately as `netPaths`.
- The tier is the highest tier any path matches.
- The agent may raise the tier, never lower it.
- Any protected-path match sets `protected: true`.
- Tests cover:
  - the computed range for a multi-change stack in which only an earlier change touches a protected path: the result is `protected: true`;
  - rejection of a supplied range that does not cover the whole stack, such as one starting at `@-`;
  - trunk resolved from the local trunk bookmark when it is a landed change ahead of `main@origin`, and a stop when it is behind, diverged, or conflicted;
  - policy and `test` loaded from trunk when the change edits `risk.toml`;
  - a missing `risk.toml` → `high`;
  - the new built-in protected paths;
  - an empty single-parent `@`, an empty merge (which is the head), a multi-change stack, renames, deletes, and paths with spaces;
  - a high-tier or protected path touched and then reverted, renamed away and back, and touched only on a merged branch.

**Required evidence by tier:**

| Tier | Evidence |
|---|---|
| low | `hk check --all` (default profile) plus `risk.toml`'s `test` command exactly as declared, self-reported with command receipts; the controller spot-checks them. Without a declared `test`, the grade stops at `type-check-only` (D14). |
| medium | everything for low, plus the affected features' verify recipes, with evidence paths |
| high | everything for medium, plus a verifier from a different model family than the implementer that runs the verify skill on the final change, plus a regression check against trunk. If the harness cannot select a different model family, the verdict is `blocked`. With no verify skill yet, see D14. |

If the project has no verify skill yet (D14), the recipe evidence is recorded as unavailable. The grade stops at the highest level actually earned, at most `unit-tested`, a high-tier row needs no verifier, and Attention says the verify skill is missing. A missing declared `test` is the second setup gap; `blocked` covers only missing required evidence.

**Verdict row:** `verdict.mjs append` reclassifies the stack itself; it never reads a classification file (D12e). It appends one JSON object to `.sjujperpowers/verdicts.jsonl` with these fields:

- change ID and commit ID;
- diff range, as from and to commit IDs;
- policy commit ID (the trunk commit that policy was loaded from) and the declared test command;
- computed tier, effective tier (raised with `--raise`), `protected`, and `protectedPaths`;
- grade, one of `failed`, `blocked`, `type-check-only`, `unit-tested`, `behavior-tested`, `live-verified`;
- for each run: command, exit status, evidence path;
- implementer and verifier model families, code-reviewer families, and whether a verify skill existed (`verifySkill`);
- timestamp.

A row is void once its commit ID, fork point, or policy commit no longer matches, or when a fresh classification at the head disagrees with it: a stored tier below the recomputed tier, or different `protected`/`protectedPaths`. Tests tamper with exactly those fields while keeping valid revision IDs: a raised low→high row stays current, and high→low, `protected` true→false, and a dropped protected path each void it. Grade, runs, and model families are self-reported and only spot-checked. Rows are evidence for the operator, never a merge gate that an agent can satisfy itself.

**Operator brief:** at most 40 lines, not counting links. Sections: Why, Scope, Tradeoffs (optional), Blast radius, Verification (each real run and its outcome, plus a line saying grade, runs, and model families are self-reported), and Attention. Attention lists protected paths touched, hunks the operator should read, parked findings, and anything the evidence could not cover. Deeper evidence is linked, not pasted.

**Integration:**

- SDD runs `verifying-by-risk` after its final review.
- executing-plans runs it before handoff.
- finishing-a-change-stack resolves the stack with the same local trunk boundary for display, conflict checks, shaping, rebase, the bookmark update, and discard. Before presenting options it:
  - shows the brief;
  - re-checks the verdict after any rebase (D4);
  - for protected changes, runs the classifier again at the landing head and asks for explicit approval naming the protected paths from that output, never from the ledger row.
- After a successful completion, finishing copies the final verdict into the Kata comment or PR body.

### hk conventions

These are a reference shipped with `verifying-by-risk`:

- Profiles (checked against hk 2.4.0): hk has no `fast` profile. Steps with no profile always run and hold static checks only. `slow` and `ci` are opt-in profiles that add the test runner; a step needs all of its positive profiles, so the runner is declared once for `slow` and once for `ci` without `slow`.
- Tests run once, as `risk.toml`'s `test` command; they are not also run through the default steps.
- jj never fires git hooks, so skills call `hk check --all` explicitly, always through `verifying-by-risk`'s `scripts/hk-check` (D13a). It also checks untracked, non-ignored files. The Rust template defines only the `check` hook, so `hk fix` is not used.
- A changed-files adapter is a follow-up. It must take revision ranges, write NUL-delimited output, and handle renames and deletes.

## nix-config (local change on `devenv-cutover`)

Changes to the Rust template:

- **`nix/hk.nix`:** fetches prebuilt upstream release binaries with `fetchurl`. Linux uses the musl builds and macOS uses aarch64-darwin. SRI hashes are converted from the release API's per-asset `digest` fields; the `.sha256` assets describe the Pkl package, not the binaries.
- **`scripts/update-hk`:** resolves the latest tag, reads the digests, and rewrites `nix/hk.nix`. It also rewrites the hk Config package version in `hk.pkl` and `.hk/base/rust.pkl`, so the binary and the schema always match.
- **`hk.pkl` plus `.hk/base/rust.pkl`:**
  - the default steps (no profile) run cargo fmt check and clippy `-D warnings`;
  - the `slow` and `ci` profiles add nextest.
- **`devenv.nix`:** imports `nix/hk.nix` and drops `git-hooks`.
- **`devenv.yaml`:** drops the `git-hooks` input.
- **`justfile`:** the `lint` and `check` recipes call hk.
- **Docs:** describe the upgrade semantics from D2.

Platform evidence so far: x86_64-linux musl 2.4.0 builds, and `hk --version` prints `hk 2.4.0`. aarch64-linux and aarch64-darwin are packaged but untested.

## Bloomery pilot (B.1–B.7)

1. **B.1:** Set up D11: create a Sjujperpowers jj workspace at the candidate revision, write `.omp/config.yml`, and add its exclude entry. Every later step runs with the candidate skills, so B.2 and B.3 go through `verifying-by-risk`.
2. **B.2:** Copy `nix/hk.nix`, `scripts/update-hk`, `hk.pkl`, and `.hk/base/rust.pkl`. Remove git-hooks.nix from `devenv.nix` and `devenv.yaml`, and the generated `.pre-commit-config.yaml` with its ignore line. Reconcile with the existing `just` recipes instead of duplicating them. Trunk has no `risk.toml` yet, so this change is `high` and protected, and lands only with operator approval.
3. **B.3:** Land `.sjujperpowers/risk.toml` on `main`, declaring `test`, the rules, and protected check inputs (D13c), as its own protected change with operator approval, before any later change is classified (D5).
4. **B.4:** Generate `verify-bloomery` and its feature map, and show one full end-to-end run.
5. **B.5:** Seed rules from Bloomery's eight OMP session transcripts. Present the batch, and land only approved rules, each with red/green proof.
6. **B.6:** Deliver the D5 change through the whole loop: classification → verification → verdict → brief → finishing.
7. **B.7: Measure operator lines read per landed change (OLR):** lines the operator is asked to read at each stop (spec, plan, brief, flagged hunks).
   - Baseline: PRs #33–#37 and their plan or spec documents, plus this pilot's own spec and plan as presented for approval.
   - Pilot: every stop of the D5 change, including any spec or plan written for it.
   - The report states that the pilot sample is n=1.

## Acceptance

- `learning-from-feedback`, `creating-a-verification-skill`, `verifying-by-risk`, and the hk conventions reference have landed locally in Sjujperpowers, or are waiting for the operator's land/PR choice.
- Each new skill has a scenario under `evals/scenarios/`, with synthetic fixtures and deterministic checks:
  - `learning-from-feedback`: red/green proof and batched approval;
  - `creating-a-verification-skill`: the generated layout plus a recorded end-to-end run;
  - `verifying-by-risk`: policy from the local trunk, the whole-stack range, the protected-path override, voiding on rewrite, and a high-tier verdict that is `blocked` without a different-family verifier.
- The classification script has unit tests in `tests/` covering every case listed under Classification. An integration test in `tests/starting-a-change/` puts local trunk one landed change ahead of `main@origin`: the shown stack, the discard target, and the classified range exclude the landed change, and a diverged trunk stops both `trunk-rev` and classification.
- The nix-config change is local and unpushed. On x86_64-linux, a fresh project generated from the Rust template gets the hk version pinned in the template (2.4.0), and `hk check --all` passes in it. The operator checks aarch64-darwin.
- B.1–B.7 are complete with evidence. The D5 change has a verdict, a brief of at most 40 lines, and a finishing check that passed at the landed commit.
- A report on SJUP-2 covers what worked, what did not, the measured OLR before and after (pilot n=1), and recommendations on hk and on next steps toward self-merge.

## Limitations

- **Local trunk is the trust root.** Policy, the test command, and protected-path detection come from the commit local `main` points to. Any agent with write access to the repository can move that bookmark, so these protect against accidents, not adversaries. That is acceptable for this pilot because verdicts are evidence, not a gate. Before any self-merge, the trust root must become something agents cannot move, such as published `main` or a landing record signed by the operator.
- **Local trunk stops.** The Sjujperpowers trunk change (plan Task 1) affects every user, not only this pilot, and lands as its own first change. After the operator pushes from another machine, local `main` is behind or diverged from `main@origin` and `trunk-rev`, classification, finishing, and `fresh-change` stop until it is reconciled. Each stop prints the command; `docs/upstream-sync.md` and the starting-a-change skill explain it.
- **Agent-run checks.** "CI" is the agent's own finishing run (D8). The brief says so.
- **Review size.** The implementation plan is about 4,000 lines against a 210-line spec, the burden SJUP-2 targets. The operator approves on the spec's decisions and acceptance and the plan's Global Constraints, and per-task reviewers cover task detail. B.7's baseline counts this plan as lines read.

## Out of scope

- Self-merge.
- GitHub or Iron policy changes, including the proxy's unchecked private-repo push target. That is a homelab fix tracked separately.
- Homelab pin bumps.
- GitHub Actions (D8).
- A shared hk base (D2).
- The changed-files adapter.
- Verification-skill maintenance mode.
- `~/dev/sjujperpowers-continuation`.
- Pushes.
