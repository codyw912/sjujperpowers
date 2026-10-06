# Workflow Outcome Eval Design

**Outcome:** plane:SJUP-2

## Summary

The scenario evals under `evals/` show that each skill changes agent behavior. They do not show whether the whole workflow lands better code, or how much the operator reads to get it. This eval answers that: the same coding agent takes the same rough feature idea to a landed change, once with the Sjujperpowers skills and once without. A verifier the agent never sees scores the result, and each trial records operator lines read (OLR), cost, and wall time.

The eval is a Yacht custom eval. Task content, scripts, and results live in a separate Yacht eval repository that follows that repository's conventions. This spec fixes the design; it adds nothing to Sjujperpowers' skills.

## Decisions

- **D1 — Full lifecycle from a rough idea.** The treatment runs the whole workflow: brainstorming, spec, plan, execution, verifying-by-risk, and finishing. Tasks begin as a rough idea, not a spec, and no existing task fixture is reused, because taking an idea to a finished, verified feature is what the workflow claims to do.
- **D2 — Two arms, one difference.** Both arms use the same task image, instruction, model, pinned OMP version, execution limits, and scripted follow-ups. The treatment adds one Yacht rigging; nothing else differs. Arms are Yacht vessels joined by a comparison.
- **D3 — Skills shipped by rigging from a pinned commit.** A script in the eval repository renders the rigging from a named Sjujperpowers commit: one `skill` install per skill directory, with every other file in that directory as `resources`. Yacht records a content digest for each skill, so a result names the exact skills it tested.
- **D4 — Bootstrap and executable scripts are treatment setup.** OMP lists the skills but loads no bootstrap. The rigging's `instructions` tell the agent to start with `using-sjujperpowers`, as the Pi and Claude Code bootstraps do. Yacht writes resources without file modes, so the rigging adds a `custom-command` step that marks every file under each skill's `scripts/` directory executable. Yacht runs commands after writing files.
- **D5 — Pre-authorized operator.** `instruction.md` holds the rough idea and an operator brief: the decisions already made, latitude on anything else, inline or subagent execution at the agent's choice, and "land locally on `main`, no push." Retained mode then sends the same fixed follow-up, `Approved. Continue as the brief says.`, eight times. A model playing the operator is out of scope: it needs conditional turns, which Yacht does not support.
- **D6 — Fixture repositories the skills can run in.** Each task image holds a colocated jj repository with a local `main`, a committed `.sjujperpowers/config.json` selecting `file` roadmap and `session` execution, and a committed `.sjujperpowers/risk.toml` with a `test` command and tiers that keep the task at `medium` or below. A `high` tier needs a verifier from a different model family, which a single-model trial cannot supply. The fixture has no `hk.pkl` and no `verify-<project>` skill, so the treatment's grade tops out at `unit-tested` (the declared test passed) and never reaches the levels that need verify recipes; the report says so. The baseline gets the identical repository.
- **D7 — Quality is hidden tests on landed `main`.** `tests/test.sh` runs `jj git import` first, so a `main` moved with plain git counts the same as one moved with jj, then checks out the final local `main` and runs hidden tests that assert only requirements the idea states. It writes `reward.json` with `resolved` (all hidden tests pass) and `fraction` (share passed). Work that never reaches `main` scores 0: both arms are told to land on `main`, and landing is part of the job. Each task ships `solution/solve.sh` so the verifier is proven at zero model cost.
- **D8 — OLR is counted the same way for both arms.** An offline script reads each trial's transcript. A stop is the agent's last message before each scripted follow-up and its final message. OLR is the lines of every stop, plus the lines of each repository file a stop asks the operator to review (for example a spec or plan path), counted once per file version. The script reports OLR per trial and per stop.
- **D9 — Cost and time come from Yacht.** Per-trial `cost_usd` is an SDK estimate, not billing, and is reported as one. Wall time is the trial's wall clock.

## Tasks

Three tasks in small Python or Node repositories, each a feature that needs several files and has at least one requirement that is stated plainly but is easy to miss (an edge case, an error path, a compatibility rule). Each task directory has the Yacht layout: `task.toml`, `instruction.md`, `environment/Dockerfile`, `solution/solve.sh`, and `tests/test.sh`. Hidden tests never enter the agent's image. Visible tests in the repository may exist, but they are not the score.

## Execution limits

Retained mode with eight follow-ups. The starting limits are 200 loop turns per message, 30 minutes per message, and 90 minutes per trial; the smoke run sets the final values. A trial that hits a limit is scored, not dropped: running out of budget is an outcome.

## Validity checks

The smoke run must show all of the following before any scored run:

- Yacht reports `brainstorming` as `loaded: observed` in the treatment and not loaded in the baseline.
- In the treatment, `fresh-change` and `trunk-rev` run without a permission error, and `classify-risk.mjs` and `verdict.mjs` produce a current ledger row.
- `solution/solve.sh` scores `resolved`, and an empty change scores 0.
- The OLR script's per-stop counts match a hand count on one trial per arm.

In scored runs, a treatment trial where `brainstorming` never loads is reported separately as a setup failure, not pooled as a workflow result.

## Runs and reporting

1. Smoke: one task, one repetition, both arms.
2. Scored: three tasks, three repetitions, both arms (18 trials).

Each run needs the operator's approval, with a spending cap, before it starts. The report gives, per arm: resolved rate and mean `fraction`, OLR (median and range, plus per-stop breakdown for the treatment), cost, and wall time. It includes Yacht's paired comparison across repetitions and says plainly when the sample cannot separate the arms from noise.

## Limitations

- The baseline receives approvals it never asked for. It may treat them as noise or as permission to continue; either is part of its behavior.
- Pre-authorized approvals mean the approval stops are not themselves tested: the eval measures what the workflow produces and how much it asks the operator to read, not whether an operator would approve.
- One model and one harness. Results do not transfer to other models without rerunning.
- No `verify-<project>` skill and no high tier, so the higher verification levels are not exercised.
- Nine trials per arm detect only large differences.

## Out of scope

- A model-played operator or conditional follow-ups.
- Other harnesses or models.
- Generating a verify skill inside the trial.
- Changes to any Sjujperpowers skill.
- Changes to the Yacht runtime.
