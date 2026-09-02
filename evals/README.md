# Skill behavior evals

Ports of a small set of scenarios from upstream's
[superpowers-evals](https://github.com/prime-radiant-inc/superpowers-evals)
(the Quorum lab), rewritten for jj and for the fork's skills. The harness is
not vendored: there is no second LLM playing the human and no per-agent
provisioning. You run one scenario at a time, by hand, in whichever harness
you want to test.

Each scenario is a directory with upstream's shape:

- `story.md` — frontmatter, the persona and script for the human (you), and
  acceptance criteria you grade from the transcript.
- `setup.sh` — one line naming a fixture builder from `lib/fixtures.sh`.
- `checks.sh` — `pre()` (fixture sanity) and `post()` (deterministic
  backstop on the repository state), using the verbs in `lib/checks.sh`.

## Running one

```bash
evals/run list
evals/run setup finishing-stack-no-unprompted-discard
#   builds a throwaway jj repo, runs pre-checks, prints the story and the dir
cd <printed dir>            # start your agent here and play the story's human
evals/run post finishing-stack-no-unprompted-discard <printed dir>
```

Verdict = every acceptance criterion met (your call, from the transcript)
AND every post-check passing. A pre-check failure means the fixture is
misconfigured, not that the agent failed.

## Scenarios

| Scenario | Exercises | Ported from |
|---|---|---|
| `triggering-finishing-a-change-stack` | plain "wrap this up" triggers the skill | `triggering-finishing-a-development-branch` |
| `finishing-stack-no-unprompted-discard` | 3-option menu, no discard offer | `finishing-branch-no-unprompted-discard` |
| `finishing-stack-discard-on-explicit-request` | typed `discard` gate, `jj abandon` | `finishing-branch-discard-on-explicit-request` |
| `finishing-stack-loose-plan-at-finish` | loose WIP in `@` surfaced, not landed or lost | `finishing-branch-untracked-plan-at-cleanup` |
| `finishing-stack-land-behind-trunk` | rebase + re-test before `jj bookmark set` | `finishing-branch-worktree-cleanup-on-merge` |
| `sdd-fix-loop-resumes-implementer` | planted spec gap handled via sanctioned routes | same name |
| `sdd-re-review-scoped` | mid-loop resume, scoped re-review | same name |
| `sdd-same-plan-resume` | ledger prevents re-dispatching Task 1 | same name |
| `tracking-providers-plane` | Plane outcome references flow into specs and plans without a file roadmap | new |
| `tracking-providers-kata` | checked preflight, named-plan recovery, claim-before-association, and keep-open completion | new |
| `tracking-providers-kata-landed` | landing-before-close ordering, child-before-root close, and delayed recovery cleanup | new |

## Writing one

Copy the closest scenario. Fixture builders must leave a colocated jj repo
with a local `main` bookmark at the base and `@` empty on top of the stack
(`trunk-rev` then resolves `main main` without a remote). Prefer verbs that
read repository state (`jj-file-in-rev`, `jj-bookmark-at`, `jj-count`) over
`command-succeeds` with ad-hoc jj pipelines. Prove each `post()` discriminates:
run it against a hand-made good outcome and at least one bad one before
marking the scenario `ready`.

Upstream's transcript checks (`check-transcript skill-called …`) have no
equivalent here; those expectations live in the acceptance criteria instead.
