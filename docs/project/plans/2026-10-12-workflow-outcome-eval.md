# Workflow Outcome Eval Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use sjujperpowers:subagent-driven-development (recommended) or sjujperpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build and run a two-arm Yacht custom eval in `yacht-evals` that measures whether the Sjujperpowers workflow lands better code from a rough idea, and how many lines the operator reads to get it.

**Architecture:** A new suite `evals/workflow-outcome/` in `/srv/agent-dev/projects/yacht-evals` holds three retained-mode Harbor tasks (small Python repos inside colocated jj repositories), one shared hidden-test verifier that scores the final local `main`, a renderer that vendors the skills from a pinned Sjujperpowers commit into a Yacht rigging, and offline OLR and report scripts that read trial transcripts. The baseline and treatment vessels differ only by the `sjujperpowers` rigging.

**Tech Stack:** Yacht `yacht-eval` at `2d4407cdfe802868fec2f220cdb5959649a7de84` (pinned in `yacht-evals/pyproject.toml`), Harbor launcher built from that revision, controlled OMP `18.2.6`, Python 3.12 (host scripts) and 3.11 (task images), pytest, jj `0.41.0`, Node 22, rootless Docker at `unix:///run/user/1100/docker.sock`.

**Spec:** `docs/project/specs/2026-10-06-workflow-outcome-eval-design.md`

**Source:** plane:SJUP-2

## Global Constraints

- All new files live in the yacht-evals repository (worked in the jj workspace below and landed on its local `main`); no Sjujperpowers skill and no Yacht runtime file changes.
- Both arms: same task image, instruction, model, pinned OMP version, execution limits, scripted follow-ups. The treatment adds exactly one rigging, `sjujperpowers`.
- Model for both vessels: `omp-subscriptions/openai-codex/gpt-6.1-sol:medium` (operator switched from `gpt-5.6-sol` for cost before the smoke run), declared in the suite-local `evals/workflow-outcome/riggings/models.yml` (context window 500000) because the shared `riggings/subscription-sol/models.yml` declares only `gpt-5.6-sol`; runtime harness `omp`, `harness_version = "18.2.6"`.
- Skills are vendored from Sjujperpowers commit `d345c74001e5d207aa6794a7de37f2de3888c5a7` (local `main` when this plan was written) and shipped unchanged.
- Retained mode, eight follow-ups, each exactly `Approved. Continue as the brief says.`; `max_turns = 200`, `message_timeout_seconds = 1800`, `timeout_seconds = 5400`. A trial that hits a limit is scored, not dropped.
- `reward.json` carries `reward` (1.0 only when every hidden test passes, else 0.0) and `fraction` (share of hidden tests passed). Work that never reaches local `main` scores 0.
- Hidden tests, solutions, `Task.md`, and this plan never enter an agent image or workspace.
- Task images: rootless builds only, pinned base `node:22-bookworm-slim@sha256:83f487e0a63425e5b4d146fb5e5be574bcbe1b7b843d3ebafdd95eaf7767a7e5`, jj from the release tarball with sha256 `42181a80d316ac157874c817c9945e104275114fb461d99e06e2312502f08f99`. No Docker socket mounts into task containers, no host homes, no secrets in images.
- Image builds, the smoke run, and the scored run each need the operator's explicit approval in the conversation first; inference runs also need a spending cap.
- Usage is reported as Yacht's per-trial token counts (input, cache read, output); dollar cost is not reported because the subscription models carry no prices (operator ruling after smoke run 2).
- yacht-evals's default workspace holds unrelated user WIP (`@` is the described change `nnurtuwq` with uncommitted `21-questions.html` and `evals/guardrail/FINDINGS.md`, above unlanded `rylnrpll`). Never work in, rebase, or build on it. All work happens in a separate jj workspace on `main`; commit only by fileset (`jj commit <paths> -m …`), never a bare `jj commit`.
- Plan, spec, and execution tracking stay in Sjujperpowers under `plane:SJUP-2`; nothing is added to yacht-evals's own `docs/superpowers` tracking.

## Conventions used by every task

- Repository root for every relative path below: `/srv/agent-dev/worktrees/yacht-evals-workflow-outcome`, a jj workspace of `/srv/agent-dev/projects/yacht-evals` created with `jj -R /srv/agent-dev/projects/yacht-evals workspace add --name workflow-outcome -r main /srv/agent-dev/worktrees/yacht-evals-workflow-outcome`. Suite root: `evals/workflow-outcome/` (abbreviated `$S`).
- Host test command: `direnv exec . uv run --locked pytest evals/workflow-outcome/tests -q` (the controller runs `direnv allow` once in this workspace before Task 1).
- Every Docker command runs with `DOCKER_HOST=unix:///run/user/1100/docker.sock`.
- Hidden test files are named `check_*.py`, not `test_*.py`, so a repository-wide `pytest` never collects them; the verifier passes them to pytest explicitly.
- Host suite tests are named `test_wo_*.py` so their module basenames do not collide with other suites.

## File Structure

| Path | Responsibility |
|---|---|
| `$S/shared/test.sh` | Canonical verifier: imports git refs into jj, exports local `main`, runs hidden checks, writes `reward.json`. Copied byte-for-byte to each task's `tests/test.sh`. |
| `$S/shared/setup-repo.sh` | Canonical image-build helper: turns a fixture tree into a colocated jj repo with a local `main`. Copied byte-for-byte to each task's `environment/setup-repo.sh`. |
| `$S/tasks/<task>/` | One Harbor task (`tally`, `shelf`, `slugs`): `task.toml`, `instruction.md`, `environment/{Dockerfile,setup-repo.sh,repo/}`, `solution/solve.sh`, `tests/{test.sh,repo-path,hidden/check_*.py}`. |
| `$S/render_rigging.py` | Vendors `skills/**` from a pinned Sjujperpowers commit into `$S/riggings/sjujperpowers/` and rewrites the generated rigging block in each named regatta. |
| `$S/riggings/sjp-AGENTS.md` | Treatment bootstrap installed at `~/.omp/agent/AGENTS.md`. |
| `$S/riggings/models.yml` | Both arms' OMP model declaration (`gpt-6.1-sol`, context window 500000); installed at `~/.omp/agent/models.yml` by the `subscription-sol` rigging. Added before the smoke run when the operator switched models. |
| ~~`$S/riggings/sjp-modes.ts`~~ | Removed after smoke run 2: Yacht's controlled OMP skips extension discovery, so the bootstrap `AGENTS.md` runs the chmod instead (spec D4). |
| `$S/regattas/workflow-outcome.toml` | Scored regatta: three tasks, two vessels, one comparison. |
| `$S/regattas/workflow-outcome-smoke.toml` | Smoke regatta: `tally` only, same vessels. |
| `$S/olr.py` | Per-trial stops, OLR, and skill-read detection from `yacht-execution/events.jsonl` plus the captured repository. |
| `$S/report.py` | Walks a logbook and prints the per-arm markdown report. |
| `$S/tests/test_wo_*.py` | Host tests for the verifier and fixtures, renderer, extension, OLR, report. |
| `$S/Task.md` | Collocated task spec: status, outcome, images, gates, run commands. Never copied into images. |
| `README.md` | One new row in the eval table. |

---

### Task 1: Shared verifier and the `tally` task

**Files:**
- Create: `$S/shared/test.sh`, `$S/shared/setup-repo.sh`
- Create: `$S/tasks/tally/task.toml`, `$S/tasks/tally/instruction.md`
- Create: `$S/tasks/tally/environment/Dockerfile`, `$S/tasks/tally/environment/setup-repo.sh` (copy of shared)
- Create: `$S/tasks/tally/environment/repo/` (`.gitignore`, `conftest.py`, `README.md`, `sample.csv`, `tally/__init__.py`, `tally/__main__.py`, `tests/test_total.py`, `.sjujperpowers/config.json`, `.sjujperpowers/risk.toml`)
- Create: `$S/tasks/tally/solution/solve.sh`
- Create: `$S/tasks/tally/tests/test.sh` (copy of shared), `$S/tasks/tally/tests/repo-path`, `$S/tasks/tally/tests/hidden/check_by_month.py`
- Test: `$S/tests/test_wo_tasks.py`

**Interfaces:**
- Produces: `shared/test.sh` contract — env `REPO` (default: contents of `$(dirname "$0")/repo-path`), `HIDDEN` (default `$(dirname "$0")/hidden`), `REWARD_DIR` (default `/logs/verifier`); writes `$REWARD_DIR/reward.json` `{"reward": 0.0|1.0, "fraction": <0..1>}` and `$REWARD_DIR/junit.xml`; exits 0 after scoring, 2 on verifier infrastructure failure.
- Produces: `shared/setup-repo.sh SRC DEST` — copies `SRC` into `DEST`, runs `jj git init --colocate`, commits everything as `Initial project`, creates bookmark `main` on it.
- Produces: `solution/solve.sh` contract — env `WORKSPACE` (default `/workspace/<task>`), `SOLVE_VCS` (`jj` default, or `git` to move `main` with plain git).
- Produces: `TASKS = ["tally"]` in `test_wo_tasks.py`; Tasks 2 and 3 extend it.

- [ ] **Step 1: Write the shared verifier**

`$S/shared/test.sh`:

```bash
#!/usr/bin/env bash
# Hidden-test verifier. Scores the final local `main`, never the working copy.
# reward.json: reward 1.0 only when every hidden check passes; fraction = share passed.
# Exit 0 after scoring; exit 2 on verifier infrastructure failure (no agent score).
set -uo pipefail

HERE=$(cd "$(dirname "$0")" && pwd)
REPO="${REPO:-$(cat "$HERE/repo-path")}"
HIDDEN="${HIDDEN:-$HERE/hidden}"
REWARD_DIR="${REWARD_DIR:-/logs/verifier}"
mkdir -p "$REWARD_DIR"

infra() {
  echo "verifier infrastructure: $1" >&2
  exit 2
}

score() {
  printf '{"reward": %s, "fraction": %s}\n' "$1" "$2" > "$REWARD_DIR/reward.json" || infra "cannot write reward.json"
  exit 0
}

command -v jj >/dev/null 2>&1 || infra "jj missing"
command -v git >/dev/null 2>&1 || infra "git missing"
python3 -c 'import pytest' 2>/dev/null || infra "python3 or pytest missing"
compgen -G "$HIDDEN/check_*.py" >/dev/null || infra "hidden checks missing"

# The agent may have deleted or broken the repository; that is its outcome.
cd "$REPO" 2>/dev/null || score 0.0 0.0
# Pick up a main moved with plain git, so it counts the same as one moved with jj.
jj git import >/dev/null 2>&1 || score 0.0 0.0
commit=$(jj log --ignore-working-copy -r 'main' --no-graph -T 'commit_id ++ "\n"' 2>/dev/null)
[ "$(printf '%s\n' "$commit" | grep -c .)" -eq 1 ] || score 0.0 0.0

WORK=$(mktemp -d) || infra "cannot create export dir"
git -C "$REPO" archive "$commit" | tar -x -C "$WORK" || score 0.0 0.0
cd "$WORK" || infra "cannot enter export"

INI_DIR=$(mktemp -d) || infra "cannot create pytest ini dir"
INI="$INI_DIR/pytest.ini"
printf '[pytest]\n' > "$INI" || infra "cannot write pytest ini"
timeout 300 python3 -P -m pytest -q -p no:cacheprovider -c "$INI" --confcutdir "$HIDDEN" --rootdir "$HIDDEN" -o pythonpath="$WORK" \
  --junitxml="$REWARD_DIR/junit.xml" "$HIDDEN"/check_*.py
rc=$?
case "$rc" in
  0|1|2|124) ;;
  *) infra "pytest exit $rc" ;;
esac

fraction=$(python3 - "$REWARD_DIR/junit.xml" <<'PY'
import sys
import xml.etree.ElementTree as ET

try:
    root = ET.parse(sys.argv[1]).getroot()
except (OSError, ET.ParseError):
    print("0.0")
    raise SystemExit
suites = [root] if root.tag == "testsuite" else list(root)
total = sum(int(s.get("tests", 0)) for s in suites)
bad = sum(
    int(s.get("failures", 0)) + int(s.get("errors", 0)) + int(s.get("skipped", 0))
    for s in suites
)
print(f"{(total - bad) / total:.4f}" if total else "0.0")
PY
)

[ "$rc" -eq 0 ] && [ "$fraction" = "1.0000" ] && score 1.0 "$fraction"
score 0.0 "$fraction"
```

`$S/shared/setup-repo.sh`:

```bash
#!/usr/bin/env bash
# Image-build helper: make SRC into a colocated jj repository at DEST with a local main.
set -euo pipefail
src=$1
dest=$2
mkdir -p "$dest"
cp -a "$src"/. "$dest"/
cd "$dest"
jj git init --colocate
jj commit -m "Initial project"
jj bookmark create main -r @-
jj log -r main --no-graph -T 'commit_id ++ "\n"'
```

Copy both into the task: `cp $S/shared/test.sh $S/tasks/tally/tests/test.sh && cp $S/shared/setup-repo.sh $S/tasks/tally/environment/setup-repo.sh`. Write `$S/tasks/tally/tests/repo-path` containing exactly `/workspace/tally` and a trailing newline.

- [ ] **Step 2: Write the `tally` fixture repository**

`environment/repo/tally/__init__.py`: empty file.

`environment/repo/tally/__main__.py`:

```python
import argparse
import csv
import sys
from decimal import Decimal


def read_rows(path):
    with open(path, newline="") as handle:
        return list(csv.DictReader(handle))


def total(rows):
    return sum((Decimal(row["amount"]) for row in rows), Decimal(0))


def main(argv=None):
    parser = argparse.ArgumentParser(prog="tally")
    sub = parser.add_subparsers(dest="command", required=True)
    p_total = sub.add_parser("total", help="print the sum of all amounts")
    p_total.add_argument("file")
    args = parser.parse_args(argv)
    if args.command == "total":
        print(f"{total(read_rows(args.file)):.2f}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
```

`environment/repo/sample.csv`:

```text
date,category,amount
2026-01-03,groceries,54.20
2026-01-15,rent,1200.00
2026-02-02,groceries,61.75
```

`environment/repo/tests/test_total.py`:

```python
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent


def test_total_of_sample():
    result = subprocess.run(
        [sys.executable, "-m", "tally", "total", str(ROOT / "sample.csv")],
        capture_output=True,
        text=True,
        cwd=ROOT,
        check=True,
    )
    assert result.stdout.strip() == "1315.95"
```

`environment/repo/conftest.py`:

```python
# Puts the repository root on sys.path so `import tally` works under any pytest rootdir.
```

`environment/repo/.gitignore`:

```text
__pycache__/
.pytest_cache/
```

`environment/repo/README.md`:

```markdown
# tally

Small CLI for expense CSV files (`date,category,amount`).

    python3 -m tally total sample.csv

Run the tests with `python3 -m pytest -q`.
```

`environment/repo/.sjujperpowers/config.json`:

```json
{"version":1,"roadmap":{"provider":"file"},"execution":{"provider":"session"}}
```

`environment/repo/.sjujperpowers/risk.toml`:

```toml
version = 1
default = "low"
test = "python3 -m pytest -q"
```

- [ ] **Step 3: Write the idea, task config, and image**

`$S/tasks/tally/instruction.md` (the operator brief section is identical in all three tasks):

```markdown
# Monthly totals for tally

This repository is `tally`, a small CLI for expense CSV files. I'd like a
monthly view.

Add a `by-month` command: `python3 -m tally by-month FILE` prints one line per
calendar month that has rows, oldest month first, as `YYYY-MM`, a tab, and the
month's total with two decimals. Refunds are negative amounts and reduce their
month's total. Money must add up exactly (no floating-point drift). If any
row's amount is not a number, print `error: line N: bad amount` to stderr,
where N is the file line number (the header is line 1), print nothing to
stdout, and exit with status 2. The existing `total` command must keep working.

## Operator brief

I'm the operator. I'll answer each time you stop, and my answers are short:

- Any design or naming choice not fixed above is yours. Pick the simplest one that meets the idea.
- Implement it yourself in this session. Do not dispatch subagents.
- Whenever you need my approval for a design, spec, plan, or result, stop and ask me. Each reply from me will be an approval.
- Land the finished work locally on this repository's `main` bookmark. Do not push; there is no remote.
- The test command is `python3 -m pytest -q`.
```

`$S/tasks/tally/task.toml`:

```toml
artifacts = [
  { source = "/workspace/tally", destination = "repo" },
]

[environment]
docker_image = "yacht-evals/workflow-outcome-tally:v1"
workdir = "/workspace/tally"

[metadata]
author = "yacht-evals"
description = "Take a rough idea (monthly totals) to a change landed on local main."
difficulty = "medium"

[verifier]
timeout_sec = 600.0

[agent]
# Execution timeout_seconds 5400 plus 300s shutdown/capture margin.
timeout_sec = 5700.0

[execution]
mode = "retained"
max_turns = 200
message_timeout_seconds = 1800
timeout_seconds = 5400

[[execution.turns]]
id = "F1"
instruction = "Approved. Continue as the brief says."

[[execution.turns]]
id = "F2"
instruction = "Approved. Continue as the brief says."

[[execution.turns]]
id = "F3"
instruction = "Approved. Continue as the brief says."

[[execution.turns]]
id = "F4"
instruction = "Approved. Continue as the brief says."

[[execution.turns]]
id = "F5"
instruction = "Approved. Continue as the brief says."

[[execution.turns]]
id = "F6"
instruction = "Approved. Continue as the brief says."

[[execution.turns]]
id = "F7"
instruction = "Approved. Continue as the brief says."

[[execution.turns]]
id = "F8"
instruction = "Approved. Continue as the brief says."
```

`$S/tasks/tally/environment/Dockerfile`:

```dockerfile
FROM node:22-bookworm-slim@sha256:83f487e0a63425e5b4d146fb5e5be574bcbe1b7b843d3ebafdd95eaf7767a7e5

# Harbor OMP install needs bash/curl/git/ca-certificates plus Node 22.
# Skills need jj and node; the fixture and verifier need python3 with pytest.
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        bash \
        ca-certificates \
        curl \
        git \
        python3 \
        python3-pytest \
    && rm -rf /var/lib/apt/lists/*

ADD --checksum=sha256:42181a80d316ac157874c817c9945e104275114fb461d99e06e2312502f08f99 \
    https://github.com/jj-vcs/jj/releases/download/v0.41.0/jj-v0.41.0-x86_64-unknown-linux-musl.tar.gz \
    /tmp/jj.tgz
RUN tar -xzf /tmp/jj.tgz -C /usr/local/bin ./jj && rm /tmp/jj.tgz && jj --version

ENV JJ_USER="Eval Operator" \
    JJ_EMAIL="operator@example.invalid" \
    GIT_AUTHOR_NAME="Eval Operator" \
    GIT_AUTHOR_EMAIL="operator@example.invalid" \
    GIT_COMMITTER_NAME="Eval Operator" \
    GIT_COMMITTER_EMAIL="operator@example.invalid"

COPY repo/ /opt/fixture/
COPY setup-repo.sh /opt/setup-repo.sh
RUN bash /opt/setup-repo.sh /opt/fixture /workspace/tally \
    && rm -rf /opt/fixture /opt/setup-repo.sh

WORKDIR /workspace/tally
```

- [ ] **Step 4: Write the hidden checks**

`$S/tasks/tally/tests/hidden/check_by_month.py`:

```python
import subprocess
import sys
from pathlib import Path

HEADER = "date,category,amount\n"


def run(tmp_path, csv_text, *args):
    data = tmp_path / "data.csv"
    data.write_text(csv_text)
    return subprocess.run(
        [sys.executable, "-m", "tally", *args, str(data)],
        capture_output=True,
        text=True,
        check=False,
        cwd=Path.cwd(),
    )


def test_groups_by_month_oldest_first(tmp_path):
    result = run(
        tmp_path,
        HEADER
        + "2026-03-02,food,10.00\n"
        + "2026-01-15,rent,500\n"
        + "2025-12-31,gift,20.00\n"
        + "2026-03-20,food,2.50\n",
        "by-month",
    )
    assert result.returncode == 0
    assert result.stdout.splitlines() == [
        "2025-12\t20.00",
        "2026-01\t500.00",
        "2026-03\t12.50",
    ]


def test_refunds_reduce_month_total(tmp_path):
    result = run(tmp_path, HEADER + "2026-02-01,shop,40.00\n2026-02-03,shop,-15.25\n", "by-month")
    assert result.returncode == 0
    assert result.stdout.splitlines() == ["2026-02\t24.75"]


def test_amounts_add_exactly(tmp_path):
    rows = "".join("2026-04-01,misc,0.10\n" for _ in range(3))
    result = run(tmp_path, HEADER + rows, "by-month")
    assert result.stdout.splitlines() == ["2026-04\t0.30"]


def test_large_amounts_do_not_drift(tmp_path):
    # Binary floats print 1000000000000000.38 here; exact decimal arithmetic prints .30.
    result = run(tmp_path, HEADER + "2026-06-01,a,1000000000000000.10\n2026-06-02,b,0.20\n", "by-month")
    assert result.stdout.splitlines() == ["2026-06\t1000000000000000.30"]


def test_bad_amount_names_line_and_prints_nothing(tmp_path):
    result = run(tmp_path, HEADER + "2026-05-01,a,1.00\n2026-05-02,b,abc\n", "by-month")
    assert result.returncode == 2
    assert result.stdout == ""
    assert "error: line 3: bad amount" in result.stderr


def test_total_still_works(tmp_path):
    result = run(tmp_path, HEADER + "2026-01-01,a,1.50\n2026-02-01,b,2.25\n", "total")
    assert result.returncode == 0
    assert result.stdout.strip() == "3.75"
```

- [ ] **Step 5: Write the host test for verifier and fixtures**

`$S/tests/test_wo_tasks.py`:

```python
import json
import os
import shutil
import subprocess
from pathlib import Path

import pytest

SUITE = Path(__file__).resolve().parent.parent
TASKS = ["tally"]
ENV = {
    **os.environ,
    "JJ_USER": "Eval Operator",
    "JJ_EMAIL": "operator@example.invalid",
    "GIT_AUTHOR_NAME": "Eval Operator",
    "GIT_AUTHOR_EMAIL": "operator@example.invalid",
    "GIT_COMMITTER_NAME": "Eval Operator",
    "GIT_COMMITTER_EMAIL": "operator@example.invalid",
}


def fixture_repo(task, tmp_path):
    repo = tmp_path / task
    subprocess.run(
        ["bash", str(SUITE / "shared" / "setup-repo.sh"), str(SUITE / "tasks" / task / "environment" / "repo"), str(repo)],
        check=True,
        capture_output=True,
        env=ENV,
    )
    return repo


def verify(task, repo, tmp_path):
    reward_dir = tmp_path / "reward"
    if reward_dir.exists():
        shutil.rmtree(reward_dir)
    tests = SUITE / "tasks" / task / "tests"
    result = subprocess.run(
        ["bash", str(tests / "test.sh")],
        env={**ENV, "REPO": str(repo), "HIDDEN": str(tests / "hidden"), "REWARD_DIR": str(reward_dir)},
        capture_output=True,
        text=True,
        check=False,
    )
    assert result.returncode == 0, result.stderr
    return json.loads((reward_dir / "reward.json").read_text())


def solve(task, repo, vcs="jj"):
    subprocess.run(
        ["bash", str(SUITE / "tasks" / task / "solution" / "solve.sh")],
        env={**ENV, "WORKSPACE": str(repo), "SOLVE_VCS": vcs},
        check=True,
        capture_output=True,
    )


@pytest.mark.parametrize("task", TASKS)
def test_shared_copies_are_identical(task):
    task_dir = SUITE / "tasks" / task
    assert (task_dir / "tests" / "test.sh").read_bytes() == (SUITE / "shared" / "test.sh").read_bytes()
    assert (task_dir / "environment" / "setup-repo.sh").read_bytes() == (SUITE / "shared" / "setup-repo.sh").read_bytes()
    assert (task_dir / "tests" / "repo-path").read_text() == f"/workspace/{task}\n"


@pytest.mark.parametrize("task", TASKS)
def test_untouched_fixture_scores_zero(task, tmp_path):
    reward = verify(task, fixture_repo(task, tmp_path), tmp_path)
    assert reward["reward"] == 0.0
    assert reward["fraction"] < 1.0


@pytest.mark.parametrize("task", TASKS)
def test_fixture_visible_tests_pass(task, tmp_path):
    repo = fixture_repo(task, tmp_path)
    subprocess.run(["python3", "-m", "pytest", "-q", "-p", "no:cacheprovider"], cwd=repo, check=True, capture_output=True)


@pytest.mark.parametrize("task", TASKS)
def test_solution_landed_with_jj_scores_one(task, tmp_path):
    repo = fixture_repo(task, tmp_path)
    solve(task, repo)
    assert verify(task, repo, tmp_path) == {"reward": 1.0, "fraction": 1.0}


@pytest.mark.parametrize("task", TASKS)
def test_solution_landed_with_plain_git_scores_one(task, tmp_path):
    repo = fixture_repo(task, tmp_path)
    solve(task, repo, vcs="git")
    assert verify(task, repo, tmp_path) == {"reward": 1.0, "fraction": 1.0}


@pytest.mark.parametrize("task", TASKS)
def test_solution_left_off_main_scores_zero(task, tmp_path):
    repo = fixture_repo(task, tmp_path)
    solve(task, repo)
    subprocess.run(["jj", "bookmark", "set", "main", "-r", "@--", "--allow-backwards"], cwd=repo, check=True, capture_output=True, env=ENV)
    assert verify(task, repo, tmp_path)["reward"] == 0.0


def test_missing_repository_scores_zero(tmp_path):
    reward = verify("tally", tmp_path / "gone", tmp_path)
    assert reward == {"reward": 0.0, "fraction": 0.0}
```

- [ ] **Step 6: Run the test to verify it fails**

Run: `direnv exec . uv run --locked pytest evals/workflow-outcome/tests/test_wo_tasks.py -q`
Expected: FAIL — `test_solution_*` error because `solution/solve.sh` does not exist; the untouched-fixture, visible-test, copy, and missing-repo tests pass.

- [ ] **Step 7: Write the solution**

`$S/tasks/tally/solution/solve.sh`:

```bash
#!/usr/bin/env bash
# Reference solution: implements the idea and lands it on local main.
set -euo pipefail
cd "${WORKSPACE:-/workspace/tally}"

cat > tally/__main__.py <<'PY'
import argparse
import csv
import sys
from decimal import Decimal, InvalidOperation


def read_rows(path):
    with open(path, newline="") as handle:
        return list(csv.DictReader(handle))


def total(rows):
    return sum((Decimal(row["amount"]) for row in rows), Decimal(0))


def by_month(path):
    totals = {}
    with open(path, newline="") as handle:
        reader = csv.DictReader(handle)
        for row in reader:
            try:
                amount = Decimal(row["amount"])
            except (InvalidOperation, TypeError):
                raise ValueError(f"line {reader.line_num}: bad amount") from None
            if not amount.is_finite():
                raise ValueError(f"line {reader.line_num}: bad amount")
            month = row["date"][:7]
            totals[month] = totals.get(month, Decimal("0")) + amount
    return sorted(totals.items())


def main(argv=None):
    parser = argparse.ArgumentParser(prog="tally")
    sub = parser.add_subparsers(dest="command", required=True)
    p_total = sub.add_parser("total", help="print the sum of all amounts")
    p_total.add_argument("file")
    p_month = sub.add_parser("by-month", help="print totals per calendar month")
    p_month.add_argument("file")
    args = parser.parse_args(argv)
    if args.command == "total":
        print(f"{total(read_rows(args.file)):.2f}")
    elif args.command == "by-month":
        try:
            months = by_month(args.file)
        except ValueError as error:
            print(f"error: {error}", file=sys.stderr)
            return 2
        for month, amount in months:
            print(f"{month}\t{amount:.2f}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
PY

if [ "${SOLVE_VCS:-jj}" = git ]; then
  git add -A
  git commit -q -m "Add by-month report"
  git update-ref refs/heads/main HEAD
else
  jj commit -m "Add by-month report"
  jj bookmark set main -r @-
fi
```

- [ ] **Step 8: Run the tests to verify they pass**

Run: `direnv exec . uv run --locked pytest evals/workflow-outcome/tests/test_wo_tasks.py -q`
Expected: PASS (7 tests).

- [ ] **Step 9: Commit**

```bash
jj commit evals/workflow-outcome/shared evals/workflow-outcome/tasks/tally evals/workflow-outcome/tests/test_wo_tasks.py -m "Add workflow-outcome verifier and tally task"
```

### Task 2: The `shelf` task

**Files:**
- Create: `$S/tasks/shelf/` with the same layout as `tally` (`task.toml`, `instruction.md`, `environment/{Dockerfile,setup-repo.sh,repo/}`, `solution/solve.sh`, `tests/{test.sh,repo-path,hidden/check_expiry.py}`)
- Modify: `$S/tests/test_wo_tasks.py` (`TASKS`)

**Interfaces:**
- Consumes: `shared/test.sh`, `shared/setup-repo.sh`, the `solve.sh` contract (`WORKSPACE`, `SOLVE_VCS`), and `TASKS` from Task 1.
- Produces: `TASKS = ["tally", "shelf"]`.

- [ ] **Step 1: Copy shared files and write the fixture**

```bash
mkdir -p evals/workflow-outcome/tasks/shelf/{environment/repo,solution,tests/hidden}
cp evals/workflow-outcome/shared/test.sh evals/workflow-outcome/tasks/shelf/tests/test.sh
cp evals/workflow-outcome/shared/setup-repo.sh evals/workflow-outcome/tasks/shelf/environment/setup-repo.sh
printf '/workspace/shelf\n' > evals/workflow-outcome/tasks/shelf/tests/repo-path
```

`environment/repo/shelf/__init__.py`:

```python
import json
import os
import time


class Shelf:
    """A tiny persistent key-value store backed by one JSON file."""

    def __init__(self, path, clock=time.time):
        self.path = path
        self.clock = clock

    def _load(self):
        if not os.path.exists(self.path):
            return {}
        with open(self.path) as handle:
            return json.load(handle)

    def _save(self, data):
        tmp = self.path + ".tmp"
        with open(tmp, "w") as handle:
            json.dump(data, handle)
        os.replace(tmp, self.path)

    def set(self, key, value):
        data = self._load()
        data[key] = value
        self._save(data)

    def get(self, key, default=None):
        return self._load().get(key, default)
```

`environment/repo/tests/test_shelf.py`:

```python
from shelf import Shelf


def test_set_then_get_round_trips(tmp_path):
    shelf = Shelf(str(tmp_path / "data.json"))
    shelf.set("greeting", "hello")
    assert Shelf(str(tmp_path / "data.json")).get("greeting") == "hello"


def test_missing_key_returns_default(tmp_path):
    assert Shelf(str(tmp_path / "data.json")).get("nope", 7) == 7
```

`environment/repo/README.md`:

```markdown
# shelf

A tiny persistent key-value store backed by one JSON file.

    from shelf import Shelf
    shelf = Shelf("data.json")
    shelf.set("greeting", "hello")
    shelf.get("greeting")

`Shelf(path, clock=time.time)` takes an injectable clock for tests.
Run the tests with `python3 -m pytest -q`.
```

`environment/repo/conftest.py`, `.gitignore`, `.sjujperpowers/config.json`, `.sjujperpowers/risk.toml`: byte-identical to the `tally` fixture's files (copy them).

- [ ] **Step 2: Write the idea, task config, and image**

`$S/tasks/shelf/instruction.md`:

```markdown
# Expiring values for shelf

This repository is `shelf`, a tiny key-value store backed by one JSON file.
I'd like values that can expire.

`set(key, value, ttl=None)`: with `ttl` in seconds, `get` returns the default
once the store's clock reads set-time plus `ttl` or later; `ttl=None` means the
value never expires. A negative `ttl` raises `ValueError`. Add `keys()`, which
returns a sorted list of the keys that have not expired. Data files written by
the current version (a flat JSON object of key to value) must still load, with
every old value treated as never expiring, and must accept new writes.

## Operator brief

I'm the operator. I'll answer each time you stop, and my answers are short:

- Any design or naming choice not fixed above is yours. Pick the simplest one that meets the idea.
- Implement it yourself in this session. Do not dispatch subagents.
- Whenever you need my approval for a design, spec, plan, or result, stop and ask me. Each reply from me will be an approval.
- Land the finished work locally on this repository's `main` bookmark. Do not push; there is no remote.
- The test command is `python3 -m pytest -q`.
```

`$S/tasks/shelf/task.toml`: the `tally` `task.toml` with exactly these three substitutions — artifact source `/workspace/shelf`, `docker_image = "yacht-evals/workflow-outcome-shelf:v1"`, `workdir = "/workspace/shelf"`, and `description = "Take a rough idea (expiring values) to a change landed on local main."`. All `[verifier]`, `[agent]`, `[execution]`, and the eight `F1`–`F8` turns are unchanged.

`$S/tasks/shelf/environment/Dockerfile`: the `tally` Dockerfile with the two `/workspace/tally` occurrences replaced by `/workspace/shelf`.

- [ ] **Step 3: Write the hidden checks**

`$S/tasks/shelf/tests/hidden/check_expiry.py`:

```python
import json

import pytest

from shelf import Shelf


class Clock:
    def __init__(self, now=1000.0):
        self.now = now

    def __call__(self):
        return self.now


def make(tmp_path, clock):
    return Shelf(str(tmp_path / "data.json"), clock=clock)


def write_old_file(tmp_path):
    (tmp_path / "data.json").write_text(json.dumps({"a": 1, "b": "two"}))


def test_value_without_ttl_never_expires(tmp_path):
    clock = Clock()
    shelf = make(tmp_path, clock)
    shelf.set("a", 1)
    clock.now += 10**9
    assert shelf.get("a") == 1


def test_value_expires_exactly_at_ttl(tmp_path):
    clock = Clock()
    shelf = make(tmp_path, clock)
    shelf.set("a", "x", ttl=30)
    clock.now = 1029.5
    assert shelf.get("a") == "x"
    clock.now = 1030.0
    assert shelf.get("a") is None
    assert shelf.get("a", "gone") == "gone"


def test_expiry_survives_reopening(tmp_path):
    clock = Clock()
    make(tmp_path, clock).set("a", 1, ttl=5)
    clock.now = 1006.0
    assert make(tmp_path, clock).get("a") is None


def test_old_flat_file_loads_as_never_expiring(tmp_path):
    write_old_file(tmp_path)
    clock = Clock()
    shelf = make(tmp_path, clock)
    clock.now += 10**9
    assert shelf.get("a") == 1
    assert shelf.get("b") == "two"
    assert shelf.keys() == ["a", "b"]


def test_old_flat_file_accepts_new_writes(tmp_path):
    write_old_file(tmp_path)
    clock = Clock()
    shelf = make(tmp_path, clock)
    shelf.set("c", 3, ttl=10)
    assert shelf.get("a") == 1
    assert shelf.get("c") == 3


def test_old_flat_file_with_format_like_keys_keeps_its_values(tmp_path):
    (tmp_path / "data.json").write_text(json.dumps({"format": 2, "entries": {}}))
    shelf = make(tmp_path, Clock())
    shelf.set("c", 3)
    assert shelf.get("format") == 2
    assert shelf.get("entries") == {}
    assert shelf.keys() == ["c", "entries", "format"]


def test_negative_ttl_is_rejected(tmp_path):
    with pytest.raises(ValueError):
        make(tmp_path, Clock()).set("a", 1, ttl=-1)


def test_keys_skips_expired_and_sorts(tmp_path):
    clock = Clock()
    shelf = make(tmp_path, clock)
    shelf.set("b", 1)
    shelf.set("a", 2, ttl=5)
    shelf.set("c", 3, ttl=50)
    clock.now = 1010.0
    assert shelf.keys() == ["b", "c"]
```

- [ ] **Step 4: Add the task to the host test and see it fail**

In `$S/tests/test_wo_tasks.py` change `TASKS = ["tally"]` to `TASKS = ["tally", "shelf"]`.

Run: `direnv exec . uv run --locked pytest evals/workflow-outcome/tests/test_wo_tasks.py -q -k shelf`
Expected: FAIL — the three `test_solution_*[shelf]` tests error because `solution/solve.sh` is missing; the other `shelf` cases pass.

- [ ] **Step 5: Write the solution**

`$S/tasks/shelf/solution/solve.sh`:

```bash
#!/usr/bin/env bash
# Reference solution: implements the idea and lands it on local main.
set -euo pipefail
cd "${WORKSPACE:-/workspace/shelf}"

cat > shelf/__init__.py <<'PY'
import json
import os
import time

FORMAT = 2


class Shelf:
    """A tiny persistent key-value store backed by one JSON file."""

    def __init__(self, path, clock=time.time):
        self.path = path
        self.clock = clock

    def _load(self):
        if not os.path.exists(self.path):
            return {}
        with open(self.path) as handle:
            raw = json.load(handle)
        if isinstance(raw, list) and len(raw) == 2 and raw[0] == FORMAT and isinstance(raw[1], dict):
            return raw[1]
        return {key: {"value": value, "expires": None} for key, value in raw.items()}

    def _save(self, entries):
        tmp = self.path + ".tmp"
        with open(tmp, "w") as handle:
            json.dump([FORMAT, entries], handle)
        os.replace(tmp, self.path)

    def _live(self, entry):
        return entry["expires"] is None or self.clock() < entry["expires"]

    def set(self, key, value, ttl=None):
        if ttl is not None and ttl < 0:
            raise ValueError("ttl must not be negative")
        entries = self._load()
        expires = None if ttl is None else self.clock() + ttl
        entries[key] = {"value": value, "expires": expires}
        self._save(entries)

    def get(self, key, default=None):
        entry = self._load().get(key)
        if entry is None or not self._live(entry):
            return default
        return entry["value"]

    def keys(self):
        return sorted(key for key, entry in self._load().items() if self._live(entry))
PY

if [ "${SOLVE_VCS:-jj}" = git ]; then
  git add -A
  git commit -q -m "Add expiring values"
  git update-ref refs/heads/main HEAD
else
  jj commit -m "Add expiring values"
  jj bookmark set main -r @-
fi
```

- [ ] **Step 6: Run the tests to verify they pass**

Run: `direnv exec . uv run --locked pytest evals/workflow-outcome/tests/test_wo_tasks.py -q`
Expected: PASS (15 tests).

- [ ] **Step 7: Commit**

```bash
jj commit evals/workflow-outcome/tasks/shelf evals/workflow-outcome/tests/test_wo_tasks.py -m "Add shelf workflow-outcome task"
```

### Task 3: The `slugs` task

**Files:**
- Create: `$S/tasks/slugs/` with the same layout (`hidden/check_unique_slug.py`)
- Modify: `$S/tests/test_wo_tasks.py` (`TASKS`)

**Interfaces:**
- Consumes: shared verifier, setup helper, `solve.sh` contract, and `TASKS` from Tasks 1–2.
- Produces: `TASKS = ["tally", "shelf", "slugs"]`.

- [ ] **Step 1: Copy shared files and write the fixture**

```bash
mkdir -p evals/workflow-outcome/tasks/slugs/{environment/repo,solution,tests/hidden}
cp evals/workflow-outcome/shared/test.sh evals/workflow-outcome/tasks/slugs/tests/test.sh
cp evals/workflow-outcome/shared/setup-repo.sh evals/workflow-outcome/tasks/slugs/environment/setup-repo.sh
printf '/workspace/slugs\n' > evals/workflow-outcome/tasks/slugs/tests/repo-path
```

`environment/repo/slugs/__init__.py`:

```python
import re
import unicodedata


def slugify(text):
    """Lowercase ASCII words joined by hyphens: 'Crème Brûlée!' -> 'creme-brulee'."""
    normalized = unicodedata.normalize("NFKD", text).encode("ascii", "ignore").decode("ascii")
    words = re.findall(r"[a-z0-9]+", normalized.lower())
    return "-".join(words)
```

`environment/repo/tests/test_slugify.py`:

```python
from slugs import slugify


def test_words_are_joined_by_hyphens():
    assert slugify("Hello, World") == "hello-world"


def test_accents_are_folded():
    assert slugify("Crème Brûlée!") == "creme-brulee"
```

`environment/repo/README.md`:

```markdown
# slugs

URL slugs for page titles.

    from slugs import slugify
    slugify("Crème Brûlée!")  # "creme-brulee"

Run the tests with `python3 -m pytest -q`.
```

`conftest.py`, `.gitignore`, `.sjujperpowers/config.json`, `.sjujperpowers/risk.toml`: copy byte-identical from the `tally` fixture.

- [ ] **Step 2: Write the idea, task config, and image**

`$S/tasks/slugs/instruction.md`:

```markdown
# Unique page slugs

This repository is `slugs`, which turns page titles into URL slugs. Pages need
unique slugs.

Add `unique_slug(text, existing)`. It returns `slugify(text)` unless that slug
is already taken in `existing` (any iterable of slugs, compared
case-insensitively); then it appends `-2`, `-3`, and so on, using the smallest
free number. A slug is at most 40 characters including any suffix: cut the base
so the suffix still fits, then drop a trailing hyphen the cut leaves. Text with
no letters or digits uses the base `page`. `slugify` must keep its current
behavior.

## Operator brief

I'm the operator. I'll answer each time you stop, and my answers are short:

- Any design or naming choice not fixed above is yours. Pick the simplest one that meets the idea.
- Implement it yourself in this session. Do not dispatch subagents.
- Whenever you need my approval for a design, spec, plan, or result, stop and ask me. Each reply from me will be an approval.
- Land the finished work locally on this repository's `main` bookmark. Do not push; there is no remote.
- The test command is `python3 -m pytest -q`.
```

`$S/tasks/slugs/task.toml`: the `tally` `task.toml` with artifact source `/workspace/slugs`, `docker_image = "yacht-evals/workflow-outcome-slugs:v1"`, `workdir = "/workspace/slugs"`, and `description = "Take a rough idea (unique slugs) to a change landed on local main."`; everything else unchanged.

`$S/tasks/slugs/environment/Dockerfile`: the `tally` Dockerfile with both `/workspace/tally` occurrences replaced by `/workspace/slugs`.

- [ ] **Step 3: Write the hidden checks**

`$S/tasks/slugs/tests/hidden/check_unique_slug.py`:

```python
from slugs import slugify, unique_slug

LONG = "word " * 30
EIGHT_WORDS = "-".join(["word"] * 8)  # slugify(LONG)[:40] minus its trailing hyphen


def test_free_slug_is_unchanged():
    assert unique_slug("Hello World", []) == "hello-world"


def test_taken_slug_gets_smallest_free_suffix():
    assert unique_slug("Hello World", ["hello-world", "hello-world-3"]) == "hello-world-2"


def test_collisions_ignore_case():
    assert unique_slug("Hello World", ["Hello-World"]) == "hello-world-2"


def test_existing_may_be_a_generator():
    assert unique_slug("a", (slug for slug in ["a", "a-2"])) == "a-3"


def test_long_text_is_cut_to_forty_without_trailing_hyphen():
    assert unique_slug(LONG, []) == EIGHT_WORDS


def test_suffix_fits_within_forty():
    result = unique_slug(LONG, [EIGHT_WORDS])
    assert result == "word-word-word-word-word-word-word-wor-2"
    assert len(result) == 40


def test_text_without_letters_or_digits_uses_page():
    assert unique_slug("!!!", []) == "page"
    assert unique_slug("¿?", ["page"]) == "page-2"


def test_slugify_is_unchanged():
    assert slugify("Crème Brûlée!") == "creme-brulee"
```

- [ ] **Step 4: Add the task to the host test and see it fail**

In `$S/tests/test_wo_tasks.py` change `TASKS = ["tally", "shelf"]` to `TASKS = ["tally", "shelf", "slugs"]`.

Run: `direnv exec . uv run --locked pytest evals/workflow-outcome/tests/test_wo_tasks.py -q -k slugs`
Expected: FAIL — `test_solution_*[slugs]` error on the missing `solve.sh`.

- [ ] **Step 5: Write the solution**

`$S/tasks/slugs/solution/solve.sh`:

```bash
#!/usr/bin/env bash
# Reference solution: implements the idea and lands it on local main.
set -euo pipefail
cd "${WORKSPACE:-/workspace/slugs}"

cat > slugs/__init__.py <<'PY'
import re
import unicodedata

LIMIT = 40


def slugify(text):
    """Lowercase ASCII words joined by hyphens: 'Crème Brûlée!' -> 'creme-brulee'."""
    normalized = unicodedata.normalize("NFKD", text).encode("ascii", "ignore").decode("ascii")
    words = re.findall(r"[a-z0-9]+", normalized.lower())
    return "-".join(words)


def unique_slug(text, existing):
    base = slugify(text) or "page"
    taken = {slug.lower() for slug in existing}
    number = 1
    while True:
        suffix = "" if number == 1 else f"-{number}"
        candidate = base[: LIMIT - len(suffix)].rstrip("-") + suffix
        if candidate not in taken:
            return candidate
        number += 1
PY

if [ "${SOLVE_VCS:-jj}" = git ]; then
  git add -A
  git commit -q -m "Add unique slugs"
  git update-ref refs/heads/main HEAD
else
  jj commit -m "Add unique slugs"
  jj bookmark set main -r @-
fi
```

- [ ] **Step 6: Run the tests to verify they pass**

Run: `direnv exec . uv run --locked pytest evals/workflow-outcome/tests/test_wo_tasks.py -q`
Expected: PASS (21 tests).

- [ ] **Step 7: Commit**

```bash
jj commit evals/workflow-outcome/tasks/slugs evals/workflow-outcome/tests/test_wo_tasks.py -m "Add slugs workflow-outcome task"
```

### Task 4: Treatment rigging, bootstrap, and regattas

**Files:**
- Create: `$S/render_rigging.py`, `$S/riggings/sjp-AGENTS.md`, `$S/riggings/models.yml`
- Create: `$S/regattas/workflow-outcome.toml`, `$S/regattas/workflow-outcome-smoke.toml`
- Create (generated): `$S/riggings/sjujperpowers/PINNED_COMMIT`, `$S/riggings/sjujperpowers/skills/**`
- Modify: `pyproject.toml`, `uv.lock` (yacht-eval pin `d22bc12004bfd928ec46beadcdafaa4495ba9490` → `2d4407cdfe802868fec2f220cdb5959649a7de84`; only 2d4407cd accepts controlled OMP `18.2.6`)
- Test: `$S/tests/test_wo_render_rigging.py`

**Interfaces:**
- Produces: `render_rigging.py --sjp-repo PATH --commit REV --regatta FILE [--regatta FILE …]`; functions `vendor(repo: Path, commit: str, dest: Path) -> str` (returns the full commit ID), `render_block(dest: Path, regatta_dir: Path) -> str`, `replace_block(regatta: Path, block: str) -> None`; constants `BEGIN`, `END`.
- Produces: vessel names `baseline` and `sjujperpowers`, comparison `sjujperpowers-vs-baseline`, course names `workflow-outcome` and `workflow-outcome-smoke` (Tasks 6–7 use them).

- [ ] **Step 0: Pin Yacht to the controlled-OMP 18.2.6 revision**

In `pyproject.toml`, change the `yacht-eval` source `rev` from `d22bc12004bfd928ec46beadcdafaa4495ba9490` to `2d4407cdfe802868fec2f220cdb5959649a7de84` (Yacht PR #303, on Yacht's `main`). Then:

```bash
direnv exec . uv lock
direnv exec . uv sync --locked
direnv exec . uv run --locked python -c "from yacht._execution_contract import CONTROLLED_OMP_VERSION as v; print(v)"
```

Expected: `uv lock` reports `Updated yacht-eval v0.13.0 (d22bc120) -> v0.13.0 (2d4407cd)` and changes nothing else; the last command prints `18.2.6`. Commit now, before rendering anything:

```bash
jj commit pyproject.toml uv.lock -m "Pin yacht-eval to 2d4407cd for controlled OMP 18.2.6"
```

- [ ] **Step 1: Write the failing renderer test**

`$S/tests/test_wo_render_rigging.py`:

import os
import subprocess
import sys
import tomllib
from pathlib import Path

import pytest

SUITE = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(SUITE))
import render_rigging

ENV = {**os.environ, "JJ_USER": "Eval Operator", "JJ_EMAIL": "operator@example.invalid"}

REGATTA = f"""[regatta]
name = "t"

{render_rigging.BEGIN}
stale = true
{render_rigging.END}

[[vessels]]
name = "baseline"
"""


def sjp_repo(tmp_path, files):
    repo = tmp_path / "sjp"
    repo.mkdir()
    subprocess.run(["jj", "git", "init", "--colocate"], cwd=repo, check=True, capture_output=True, env=ENV)
    for rel, content in files.items():
        path = repo / rel
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(content)
    subprocess.run(["jj", "commit", "-m", "skills"], cwd=repo, check=True, capture_output=True, env=ENV)
    commit = subprocess.run(
        ["jj", "log", "-r", "@-", "--no-graph", "-T", "commit_id"], cwd=repo, check=True, capture_output=True, text=True, env=ENV
    ).stdout
    return repo, commit


FILES = {
    "skills/alpha/SKILL.md": "---\nname: alpha\n---\nA\n",
    "skills/alpha/scripts/run": "#!/usr/bin/env bash\necho hi\n",
    "skills/alpha/references/notes.md": "notes\n",
    "skills/beta/SKILL.md": "---\nname: beta\n---\nB\n",
    "README.md": "not a skill\n",
}


def test_vendor_copies_only_skills_and_pins_commit(tmp_path):
    repo, commit = sjp_repo(tmp_path, FILES)
    dest = tmp_path / "vendor"
    (dest / "skills" / "stale").mkdir(parents=True)
    assert render_rigging.vendor(repo, commit, dest) == commit
    assert (dest / "PINNED_COMMIT").read_text() == commit + "\n"
    assert (dest / "skills/alpha/scripts/run").read_text() == FILES["skills/alpha/scripts/run"]
    assert not (dest / "skills" / "stale").exists()
    assert not (dest / "README.md").exists()


def test_vendor_accepts_relative_repo_path(tmp_path, monkeypatch):
    _, commit = sjp_repo(tmp_path, FILES)
    dest = tmp_path / "vendor"
    monkeypatch.chdir(tmp_path)
    assert render_rigging.vendor(Path("sjp"), commit, dest) == commit
    assert (dest / "skills/alpha/scripts/run").read_text() == FILES["skills/alpha/scripts/run"]

def test_rendered_regatta_installs_each_skill_with_resources(tmp_path):
    repo, commit = sjp_repo(tmp_path, FILES)
    dest = tmp_path / "suite" / "riggings" / "sjujperpowers"
    regatta = tmp_path / "suite" / "regattas" / "r.toml"
    regatta.parent.mkdir(parents=True)
    regatta.write_text(REGATTA)
    render_rigging.vendor(repo, commit, dest)
    render_rigging.replace_block(regatta, render_rigging.render_block(dest, regatta.parent))

    data = tomllib.loads(regatta.read_text())
    assert "stale" not in data["regatta"]
    assert data["vessels"][0]["name"] == "baseline"
    steps = data["riggings"]["sjujperpowers"]["install"]
    skills = {s["target"]: s for s in steps if s["method"] == "skill"}
    assert set(skills) == {"alpha", "beta"}
    assert skills["alpha"]["source"] == "../riggings/sjujperpowers/skills/alpha/SKILL.md"
    assert {r["path"] for r in skills["alpha"]["resources"]} == {"scripts/run", "references/notes.md"}
    assert all((regatta.parent / r["source"]).is_file() for r in skills["alpha"]["resources"])
    assert "resources" not in skills["beta"]
    configs = {s["target"]: s for s in steps if s["method"] == "config-file"}
    assert set(configs) == {".omp/agent/AGENTS.md"}


def test_skill_directory_without_skill_md_is_rejected(tmp_path):
    repo, commit = sjp_repo(tmp_path, {**FILES, "skills/gamma/notes.md": "x\n"})
    dest = tmp_path / "vendor"
    render_rigging.vendor(repo, commit, dest)
    with pytest.raises(SystemExit, match="gamma"):
        render_rigging.render_block(dest, tmp_path)


def test_missing_markers_are_rejected(tmp_path):
    regatta = tmp_path / "r.toml"
    regatta.write_text("[regatta]\nname = 't'\n")
    with pytest.raises(SystemExit, match="markers"):
        render_rigging.replace_block(regatta, "block")
        render_rigging.replace_block(regatta, "block")
```

Run: `direnv exec . uv run --locked pytest evals/workflow-outcome/tests/test_wo_render_rigging.py -q`
Expected: FAIL with `ModuleNotFoundError: No module named 'render_rigging'`.

- [ ] **Step 2: Write the renderer**

`$S/render_rigging.py`:

#!/usr/bin/env python3
"""Vendor Sjujperpowers skills from a pinned commit and render the treatment rigging.

Usage:
  render_rigging.py --sjp-repo PATH --commit REV --regatta FILE [--regatta FILE ...]
"""
from __future__ import annotations

import argparse
import json
import os
import shutil
import subprocess
from pathlib import Path

SUITE = Path(__file__).resolve().parent
VENDOR = SUITE / "riggings" / "sjujperpowers"
AGENTS_MD = SUITE / "riggings" / "sjp-AGENTS.md"

BEGIN = "# BEGIN sjujperpowers rigging (generated by render_rigging.py; do not edit)"
END = "# END sjujperpowers rigging"


def _jj(repo: Path, *args: str) -> bytes:
    # cwd=repo: `jj file list` prints paths relative to the cwd, and vendor() needs repo-relative paths.
    return subprocess.run(
        ["jj", "-R", str(repo), "--ignore-working-copy", *args],
        cwd=repo,
        check=True,
        capture_output=True,
    ).stdout


def vendor(repo: Path, commit: str, dest: Path) -> str:
    """Copy every file under skills/ at `commit` into dest/skills; return the full commit ID."""
    # Resolve before any jj call: `-R` is resolved against cwd=repo, so a relative path would be applied twice.
    repo = Path(repo).resolve()
    files = [line for line in _jj(repo, "file", "list", "-r", commit, "root-glob:skills/**").decode().splitlines() if line]
    if not files:
        raise SystemExit(f"no skills/ files at {commit}")
    full = _jj(repo, "log", "-r", commit, "--no-graph", "-T", "commit_id").decode().strip()
    if dest.exists():
        shutil.rmtree(dest)
    for rel in files:
        out = dest / rel
        out.parent.mkdir(parents=True, exist_ok=True)
        out.write_bytes(_jj(repo, "file", "show", "-r", full, f"root-file:{json.dumps(rel)}"))
    (dest / "PINNED_COMMIT").write_text(full + "\n")
    return full


def _q(value: str) -> str:
    # TOML basic strings accept JSON string escapes.
    return json.dumps(value)


def render_block(dest: Path, regatta_dir: Path) -> str:
    """Return the generated rigging block with sources relative to regatta_dir."""
    skills_root = dest / "skills"
    lines = [
        BEGIN,
        "[tools.sjujperpowers]",
        'kind = "agent-skill"',
        'description = "Sjujperpowers workflow skills at the pinned commit."',
        'interfaces = ["agent-skill"]',
        "",
        "[riggings.sjujperpowers]",
        'tools = ["sjujperpowers"]',
        "",
    ]
    for skill_dir in sorted(p for p in skills_root.iterdir() if p.is_dir()):
        skill_md = skill_dir / "SKILL.md"
        if not skill_md.is_file():
            raise SystemExit(f"skill directory {skill_dir.name} has no SKILL.md")
        resources = sorted(p for p in skill_dir.rglob("*") if p.is_file() and p != skill_md)
        lines += [
            "[[riggings.sjujperpowers.install]]",
            'method = "skill"',
            f"target = {_q(skill_dir.name)}",
            f"source = {_q(os.path.relpath(skill_md, regatta_dir))}",
        ]
        if resources:
            lines.append("resources = [")
            for resource in resources:
                rel = resource.relative_to(skill_dir).as_posix()
                src = os.path.relpath(resource, regatta_dir)
                lines.append(f"  {{ path = {_q(rel)}, source = {_q(src)} }},")
            lines.append("]")
        lines.append("")
    lines += [
        "[[riggings.sjujperpowers.install]]",
        'method = "config-file"',
        f"target = {_q('.omp/agent/AGENTS.md')}",
        f"source = {_q(os.path.relpath(AGENTS_MD, regatta_dir))}",
        "",
    ]
    lines.append(END)
    return "\n".join(lines)


def replace_block(regatta: Path, block: str) -> None:
    text = regatta.read_text()
    start = text.find(BEGIN)
    end = text.find(END)
    if start < 0 or end < start:
        raise SystemExit(f"{regatta}: generated-block markers missing")
    regatta.write_text(text[:start] + block + text[end + len(END):])


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--sjp-repo", type=Path, required=True)
    parser.add_argument("--commit", required=True)
    parser.add_argument("--regatta", type=Path, action="append", required=True)
    args = parser.parse_args()
    full = vendor(args.sjp_repo, args.commit, VENDOR)
    for regatta in args.regatta:
        replace_block(regatta, render_block(VENDOR, regatta.resolve().parent))
    print(f"vendored sjujperpowers {full} into {VENDOR.relative_to(SUITE)}")


if __name__ == "__main__":
    main()
    main()
```

Run: `direnv exec . uv run --locked pytest evals/workflow-outcome/tests/test_wo_render_rigging.py -q`
Expected: PASS (5 tests, including the relative `--sjp-repo` test added in execution).

- [ ] **Step 3: Write the bootstrap**

Yacht's controlled OMP session sets `restrictToolNames`, and OMP 18.2.6 then skips extension discovery, so the bootstrap itself makes the skill scripts executable (spec D4). An earlier draft of this plan shipped a `sjp-modes.ts` extension for this; smoke run 2 showed it never loads.

`$S/riggings/sjp-AGENTS.md`:

```markdown
# Sjujperpowers

Before your first response in this session, run
`chmod +x ~/.agents/skills/*/scripts/*`, then read `skill://using-sjujperpowers`
and follow it. The Sjujperpowers skills are installed as `skill://<name>` and
under `~/.agents/skills/<name>/`.
```

- [ ] **Step 4: Write the regattas**

`$S/regattas/workflow-outcome.toml`:

```toml
# Workflow outcome eval (spec: sjujperpowers docs/project/specs/2026-10-06-workflow-outcome-eval-design.md).
# Two vessels; the treatment adds only the `sjujperpowers` rigging.
[regatta]
name = "workflow-outcome"

[preflight]
failure_policy = "abort-group"

[course]
name = "workflow-outcome"

[[course.tasks]]
id = "tally"
title = "Monthly totals for tally"

[[course.tasks]]
id = "shelf"
title = "Expiring values for shelf"

[[course.tasks]]
id = "slugs"
title = "Unique page slugs"

[course.adapter]
kind = "custom-eval"
dataset = "../tasks"
split = "v1"
harness = "harbor"

[secrets.openai]
source = "env"
name = "OPENAI_API_KEY"

[runtimes.harbor-omp]
backend = "harbor"
image = "yacht/harbor-launcher:workflow-outcome"
harness = "omp"
harness_version = "18.2.6"
required_secrets = ["openai"]

[runtimes.harbor-omp.preflight]
required = true
checks = [
  { name = "docker-daemon", kind = "command", command = ["docker", "info"] },
  { name = "harbor-launcher-image", kind = "command", command = ["docker", "image", "inspect", "yacht/harbor-launcher:workflow-outcome"] },
  { name = "task-image-tally", kind = "command", command = ["docker", "image", "inspect", "yacht-evals/workflow-outcome-tally:v1"] },
  { name = "task-image-shelf", kind = "command", command = ["docker", "image", "inspect", "yacht-evals/workflow-outcome-shelf:v1"] },
  { name = "task-image-slugs", kind = "command", command = ["docker", "image", "inspect", "yacht-evals/workflow-outcome-slugs:v1"] },
  { name = "openai-secret", kind = "env", env = ["OPENAI_API_KEY"] },
  { name = "agent-install", kind = "install-only" },
]

[riggings.subscription-sol]

[riggings.subscription-sol.env]
# Yacht uploads this public trust bundle before agent installation.
GIT_SSL_CAINFO = "/tmp/yacht-worker-ca-bundle.crt"
OTEL_TRACES_EXPORTER = "none"
OTEL_LOGS_EXPORTER = "none"
OTEL_METRICS_EXPORTER = "none"
OTEL_SERVICE_NAME = "yacht-omp"
OTEL_RESOURCE_ATTRIBUTES = "deployment.environment.name=homelab,host.name=agent-workstation,service.version=18.2.6"

[[riggings.subscription-sol.install]]
method = "config-file"
target = ".omp/agent/models.yml"
source = "../riggings/models.yml"

# BEGIN sjujperpowers rigging (generated by render_rigging.py; do not edit)
# END sjujperpowers rigging

[[vessels]]
name = "baseline"
model = "omp-subscriptions/openai-codex/gpt-6.1-sol:medium"
runtime = "harbor-omp"
rigging = ["subscription-sol"]

[[vessels]]
name = "sjujperpowers"
model = "omp-subscriptions/openai-codex/gpt-6.1-sol:medium"
runtime = "harbor-omp"
rigging = ["subscription-sol", "sjujperpowers"]

[[comparisons]]
name = "sjujperpowers-vs-baseline"
course = "workflow-outcome"
vessels = ["baseline", "sjujperpowers"]
```

`$S/regattas/workflow-outcome-smoke.toml`: the same file with these changes only — `[regatta] name = "workflow-outcome-smoke"`, `[course] name = "workflow-outcome-smoke"`, only the `tally` `[[course.tasks]]` entry, the `task-image-shelf` and `task-image-slugs` preflight checks removed, and the comparison's `course = "workflow-outcome-smoke"`.

- [ ] **Step 5: Render the rigging from the pinned commit and validate**

```bash
direnv exec . uv run --locked python evals/workflow-outcome/render_rigging.py \
  --sjp-repo /srv/agent-dev/projects/sjujperpowers \
  --commit d345c74001e5d207aa6794a7de37f2de3888c5a7 \
  --regatta evals/workflow-outcome/regattas/workflow-outcome.toml \
  --regatta evals/workflow-outcome/regattas/workflow-outcome-smoke.toml
direnv exec . uv run --locked yacht validate evals/workflow-outcome/regattas/workflow-outcome.toml
direnv exec . uv run --locked yacht validate evals/workflow-outcome/regattas/workflow-outcome-smoke.toml
direnv exec . uv run --locked yacht internals plan evals/workflow-outcome/regattas/workflow-outcome-smoke.toml
```

Expected: `vendored sjujperpowers d345c74001e5d207aa6794a7de37f2de3888c5a7 into riggings/sjujperpowers`; both validations succeed; `internals plan` prints the runtime plan without launching anything. `evals/workflow-outcome/riggings/sjujperpowers/skills/` holds 19 skill directories. If `yacht validate` rejects a field, fix the regatta to the schema in `yacht/src/yacht/schemas/yacht.regatta.v1.schema.json` at the pinned revision; do not change the two-vessel shape or the model.

- [ ] **Step 6: Run all host tests**

Run: `direnv exec . uv run --locked pytest evals/workflow-outcome/tests -q`
Expected: PASS (26 tests at Task 4; the `sjp-modes` extension tests were removed after smoke run 2).

- [ ] **Step 7: Commit**

```bash
jj commit evals/workflow-outcome/render_rigging.py evals/workflow-outcome/riggings evals/workflow-outcome/regattas evals/workflow-outcome/tests/test_wo_render_rigging.py -m "Add Sjujperpowers treatment rigging and workflow-outcome regattas"
```

### Task 5: OLR and the per-arm report

**Files:**
- Create: `$S/olr.py`, `$S/report.py`
- Test: `$S/tests/test_wo_olr.py`, `$S/tests/test_wo_report.py`

**Interfaces:**
- Produces (`olr.py`): `Stop(timestamp_ms: int, text: str)`; `load_events(path: Path) -> list[dict]`; `stops(events: list[dict]) -> list[Stop]`; `line_count(text: str) -> int` (non-blank lines); `review_paths(text: str, workdir: str) -> list[str]`; `RepoHistory(repo: Path | None)` with `file_at(path: str, timestamp_ms: int) -> str | None`; `skill_read_ok(events: list[dict], uri: str) -> bool`; `workdir_for(trial_dir: Path) -> str`; `measure(trial_dir: Path) -> dict` returning `{"olr": int, "stops": [{"index", "timestamp_ms", "lines", "files": [{"path", "lines", "counted"}]}]}`. CLI: `olr.py TRIAL_DIR...` prints one JSON object per line with `"trial"` added.
- Produces (`report.py`): `Trial` dataclass (`vessel, task, run, reward, fraction, cost_usd, wall_seconds, olr, setup_failure, stops`); `find_trials(logbook: Path) -> list[Trial]`; `render(trials: list[Trial]) -> str`. CLI: `report.py LOGBOOK` prints markdown.
- Consumes: trial layout `…/vessels/<vessel>/harbor-trials/harbor/<task>__<id>/` with `yacht-execution/events.jsonl`, `yacht-execution/summary.json` (`cost_usd`), `result.json` (`started_at`, `finished_at`), `verifier/reward.json` (`reward`, `fraction`), `artifacts/repo/` (the task.toml artifact); optional `runs/run-NNN/` ancestor for repetitions.

**OLR rules (from spec D8, made exact here):**
- A stop is the last assistant message with non-empty text before each user message after the first, plus the last assistant text message overall. An assistant text already used as a stop is not reused.
- Lines are non-blank lines, for stops and files alike.
- A stop "asks the operator to review" a file when its text matches `\b(review|approve|approval|sign off|look over|read through)\b` (case-insensitive) and names a repository file path (any path containing `/` or ending in a file extension, e.g. `docs/spec.md`, `tally/__main__.py`). Paths are taken relative to the repository; an absolute path is kept only when it starts with the task workdir (`/workspace/<task>/`), which is stripped. A named path that does not exist at that version is not counted.
- The file version is the content at `@` in the last jj operation at or before the stop's timestamp, read from the captured repository. A (path, content) pair counts once per trial; a file that cannot be read at that operation does not count. Known limit (spec Limitations): a file the agent wrote but no jj operation snapshotted before the stop is invisible here; `measure` reports such named-but-unreadable paths as `{"counted": false, "lines": 0, "missing": true}` so the smoke run can see how often it happens.

- [ ] **Step 1: Write the failing OLR test**

`$S/tests/test_wo_olr.py`:

```python
import json
import os
import subprocess
import sys
import time
from pathlib import Path

SUITE = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(SUITE))
import olr

ENV = {**os.environ, "JJ_USER": "Eval Operator", "JJ_EMAIL": "operator@example.invalid"}


def user(ts, text):
    return {"type": "event", "event": {"type": "message_end", "message": {"role": "user", "timestamp": ts, "content": [{"type": "text", "text": text}]}}}


def assistant(ts, text, stop_reason="stop"):
    content = [{"type": "text", "text": text}] if text else [{"type": "toolCall"}]
    message = {"role": "assistant", "timestamp": ts, "content": content, "stopReason": stop_reason}
    return {"type": "event", "event": {"type": "message_end", "message": message}}


def latest_op_ms(repo):
    out = subprocess.run(
        ["jj", "op", "log", "--ignore-working-copy", "--no-graph", "-T", 'self.time().end().format("%s%3f") ++ "\\n"'],
        cwd=repo, check=True, capture_output=True, text=True, env=ENV,
    ).stdout
    return int(out.splitlines()[0])


def spec_repo(tmp_path):
    repo = tmp_path / "tally__abc123" / "artifacts" / "repo"
    repo.mkdir(parents=True)
    subprocess.run(["jj", "git", "init", "--colocate"], cwd=repo, check=True, capture_output=True, env=ENV)
    (repo / "docs").mkdir()
    (repo / "docs" / "spec.md").write_text("one\n\ntwo\nthree\n")
    subprocess.run(["jj", "commit", "-m", "spec v1"], cwd=repo, check=True, capture_output=True, env=ENV)
    v1 = latest_op_ms(repo)
    time.sleep(0.02)
    (repo / "docs" / "spec.md").write_text("one\ntwo\nthree\nfour\nfive\n")
    subprocess.run(["jj", "commit", "-m", "spec v2"], cwd=repo, check=True, capture_output=True, env=ENV)
    v2 = latest_op_ms(repo)
    return repo, v1, v2


def test_a_stop_is_every_end_turn_text_before_each_follow_up_and_at_the_end():
    events = [
        user(1, "idea"),
        assistant(2, "working", "toolUse"),
        assistant(3, "design\nline two"),
        assistant(4, "Approve it?"),
        user(5, "Approved."),
        assistant(6, None, "toolUse"),
        user(7, "Approved."),
        assistant(8, "narration", "toolUse"),
        assistant(9, "final"),
    ]
    result = olr.stops(events)
    assert [s.text for s in result] == ["design\nline two\nApprove it?", "final"]
    assert [s.timestamp_ms for s in result] == [4, 9]


def test_line_count_ignores_blank_lines():
    assert olr.line_count("a\n\n  \nb\n") == 2


def test_review_paths_keep_relative_and_workdir_paths_only():
    text = "Please review `docs/spec.md`, tally/__main__.py, /workspace/tally/docs/plan.md, and /etc/x.md."
    assert olr.review_paths(text, "/workspace/tally") == ["docs/spec.md", "tally/__main__.py", "docs/plan.md"]

def test_review_paths_preserve_dotted_and_short_extensions():
    assert olr.review_paths("Please review config.test.py and x.c, e.g. U.S. v1.2.3", "/app") == ["config.test.py", "x.c"]


def test_files_count_once_per_version_and_only_with_a_review_cue_on_the_same_line(tmp_path):
    _repo, v1, v2 = spec_repo(tmp_path)
    trial = tmp_path / "tally__abc123"
    (trial / "yacht-execution").mkdir()
    events = [
        user(v1 - 5, "idea"),
        assistant(v1 + 1, "Please review docs/spec.md"),
        user(v1 + 2, "Approved."),
        assistant(v1 + 3, "Approve docs/spec.md again?"),
        user(v1 + 4, "Approved."),
        assistant(v2 + 1, "Updated docs/spec.md; please review"),
        user(v2 + 2, "Approved."),
        assistant(v2 + 3, "Landed. See docs/spec.md"),
        user(v2 + 4, "Approved."),
        assistant(v2 + 5, "Design: add a section to docs/spec.md\nApprove this design?"),
    ]
    (trial / "yacht-execution" / "events.jsonl").write_text("\n".join(json.dumps(e) for e in events) + "\n")

    result = olr.measure(trial)

    files = [f for stop in result["stops"] for f in stop["files"]]
    assert files == [
        {"path": "docs/spec.md", "lines": 3, "counted": True},
        {"path": "docs/spec.md", "lines": 0, "counted": False},
        {"path": "docs/spec.md", "lines": 5, "counted": True},
    ]
    assert [s["lines"] for s in result["stops"]] == [1, 1, 1, 1, 2]
    assert result["olr"] == 6 + 3 + 5

def test_messages_in_one_stop_resolve_reviewed_files_at_their_own_timestamps(tmp_path):
    _repo, v1, v2 = spec_repo(tmp_path)
    trial = tmp_path / "tally__abc123"
    (trial / "yacht-execution").mkdir()
    events = [
        user(v1 - 5, "idea"),
        assistant(v1 + 1, "Please review docs/spec.md"),
        assistant(v2 + 1, "Updated. Please review docs/spec.md"),
    ]
    (trial / "yacht-execution" / "events.jsonl").write_text("\n".join(json.dumps(e) for e in events) + "\n")

    result = olr.measure(trial)

    assert len(result["stops"]) == 1
    assert result["stops"][0]["lines"] == 2
    assert result["stops"][0]["files"] == [
        {"path": "docs/spec.md", "lines": 3, "counted": True},
        {"path": "docs/spec.md", "lines": 5, "counted": True},
    ]
    assert result["olr"] == 2 + 3 + 5
    assert result["history_error"] is None


def test_unreadable_jj_history_keeps_stop_lines_and_marks_files_missing(tmp_path):
    healthy = tmp_path / "tally__ok"
    repo = healthy / "artifacts" / "repo"
    repo.mkdir(parents=True)
    subprocess.run(["jj", "git", "init", "--colocate"], cwd=repo, check=True, capture_output=True, env=ENV)
    (repo / "docs").mkdir()
    (repo / "docs" / "spec.md").write_text("one\n\ntwo\nthree\n")
    subprocess.run(["jj", "commit", "-m", "spec v1"], cwd=repo, check=True, capture_output=True, env=ENV)
    v1 = latest_op_ms(repo)
    (healthy / "yacht-execution").mkdir()
    events = [user(v1 - 5, "idea"), assistant(v1 + 1, "Please review docs/spec.md")]
    (healthy / "yacht-execution" / "events.jsonl").write_text("\n".join(json.dumps(e) for e in events) + "\n")
    broken = tmp_path / "tally__bad"
    (broken / "yacht-execution").mkdir(parents=True)
    (broken / "artifacts" / "repo" / ".jj").mkdir(parents=True)
    (broken / "artifacts" / "repo" / ".jj" / "junk").write_text("not a repo\n")
    (broken / "yacht-execution" / "events.jsonl").write_text((healthy / "yacht-execution" / "events.jsonl").read_text())

    results = {trial.name: olr.measure(trial) for trial in (healthy, broken)}

    assert results["tally__ok"]["history_error"] is None
    assert results["tally__ok"]["stops"][0]["files"][0]["counted"] is True
    broken_result = results["tally__bad"]
    assert broken_result["stops"][0]["lines"] == 1
    assert broken_result["olr"] == 1
    assert broken_result["stops"][0]["files"] == [{"path": "docs/spec.md", "lines": 0, "counted": False, "missing": True}]
    assert broken_result["history_error"]


def test_missing_repository_counts_stop_lines_only(tmp_path):
    trial = tmp_path / "tally__x"
    (trial / "yacht-execution").mkdir(parents=True)
    events = [user(1, "idea"), assistant(2, "please review docs/spec.md\nthanks")]
    (trial / "yacht-execution" / "events.jsonl").write_text("\n".join(json.dumps(e) for e in events) + "\n")
    result = olr.measure(trial)
    assert result["olr"] == 2
    assert result["stops"][0]["files"] == [{"path": "docs/spec.md", "lines": 0, "counted": False, "missing": True}]


def test_skill_read_ok_requires_a_successful_read():
    def start(call, path):
        return {"type": "event", "event": {"type": "tool_execution_start", "toolCallId": call, "toolName": "read", "args": {"path": path}}}

    def end(call, error):
        return {"type": "event", "event": {"type": "tool_execution_end", "toolCallId": call, "toolName": "read", "isError": error}}

    ok = [start("1", "skill://brainstorming"), end("1", False)]
    failed = [start("1", "skill://brainstorming"), end("1", True)]
    other = [start("1", "skill://writing-plans"), end("1", False)]
    assert olr.skill_read_ok(ok, "skill://brainstorming")
    assert not olr.skill_read_ok(failed, "skill://brainstorming")
    assert not olr.skill_read_ok(other, "skill://brainstorming")
```

Run: `direnv exec . uv run --locked pytest evals/workflow-outcome/tests/test_wo_olr.py -q`
Expected: FAIL with `ModuleNotFoundError: No module named 'olr'`.

- [ ] **Step 2: Write `olr.py`**

`$S/olr.py`:

```python
#!/usr/bin/env python3
"""Operator lines read (OLR) for one Yacht trial, counted the same way for both arms.

A stop is every end-turn text message (not tool-call narration) the agent sends before
each scripted follow-up, and after the last one. OLR = non-blank lines of every stop +
non-blank lines of each repository file a stop asks the operator to review (path and review
cue on the same line), once per file version. Each message in a stop is resolved at its own
timestamp. A jj history that cannot be read keeps the stop-line counts and marks each
requested file missing. (Which trials are pooled is report.py's rule: infrastructure-invalid
trials and treatment setup failures are listed but excluded there, not here.)

Usage: olr.py TRIAL_DIR [TRIAL_DIR ...]   (one JSON object per line)
"""
from __future__ import annotations

import hashlib
import json
import re
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path

CUE = re.compile(r"\b(review|approve|approval|sign off|look over|read through)\b", re.IGNORECASE)
FILE_PATH = re.compile(r"(?<![\w.\-/:])(/?(?:[\w.\-]+/)+[\w\-]+(?:\.[\w\-]+)*|(?!(?i:e\.g|i\.e)\b)[A-Za-z_][\w\-]*(?:\.[\w\-]+)*\.(?:[A-Za-z][A-Za-z0-9]+|[a-z]))(?![\w/])")


@dataclass(frozen=True)
class Turn:
    timestamp_ms: int
    text: str


@dataclass(frozen=True)
class Stop:
    timestamp_ms: int
    text: str
    turns: tuple[Turn, ...]


def load_events(path: Path) -> list[dict]:
    return [json.loads(line) for line in path.read_text().splitlines() if line.strip()]


def _messages(events: list[dict]):
    for item in events:
        event = item.get("event") or {}
        if item.get("type") == "event" and event.get("type") == "message_end":
            yield event["message"]


def _text(message: dict) -> str:
    return "\n".join(block.get("text", "") for block in message.get("content") or [] if block.get("type") == "text")


def stops(events: list[dict]) -> list[Stop]:
    """Every end-turn assistant text (not a tool-call turn) between scripted follow-ups is one stop.

    OMP can re-prompt the agent after it ends a turn (e.g. an incomplete-todo reminder), so the
    operator may see several end-turn messages before the next follow-up; all of them are read.
    The stop's timestamp is its last message; each constituent message keeps its own.
    """
    result: list[Stop] = []
    turns: list[Turn] = []
    users = 0
    for message in _messages(events):
        if message.get("role") == "assistant":
            text = _text(message)
            if text.strip() and message.get("stopReason") != "toolUse":
                turns.append(Turn(int(message["timestamp"]), text))
        elif message.get("role") == "user":
            users += 1
            if users > 1 and turns:
                result.append(Stop(turns[-1].timestamp_ms, "\n".join(turn.text for turn in turns), tuple(turns)))
                turns = []
    if turns:
        result.append(Stop(turns[-1].timestamp_ms, "\n".join(turn.text for turn in turns), tuple(turns)))
    return result


def line_count(text: str) -> int:
    return sum(1 for line in text.splitlines() if line.strip())


def review_paths(text: str, workdir: str) -> list[str]:
    prefix = workdir.rstrip("/") + "/"
    found: list[str] = []
    for raw in FILE_PATH.findall(text):
        if raw.startswith("/"):
            if not raw.startswith(prefix):
                continue
            raw = raw[len(prefix):]
        path = raw.removeprefix("./")
        if path not in found:
            found.append(path)
    return found


class RepoHistory:
    """File contents at the jj operation current when a message was sent.

    A repository directory whose jj history cannot be read is unavailable: file
    lookups return None, and ``error`` carries a short message.
    """

    def __init__(self, repo: Path | None):
        self.repo = repo
        self.ops: list[tuple[int, str]] = []
        self.error: str | None = None
        if repo is None or not (repo / ".jj").is_dir():
            return
        try:
            result = subprocess.run(
                ["jj", "op", "log", "--ignore-working-copy", "--no-graph", "-T",
                 'self.id() ++ " " ++ self.time().end().format("%s%3f") ++ "\\n"'],
                cwd=repo, check=False, capture_output=True, text=True,
            )
            if result.returncode != 0:
                raise subprocess.CalledProcessError(result.returncode, result.args, result.stdout, result.stderr)
            for line in result.stdout.splitlines():
                op, ms = line.split()
                self.ops.append((int(ms), op))  # newest first
        except (OSError, subprocess.CalledProcessError, ValueError) as exc:
            self.ops = []
            detail = exc.stderr if isinstance(exc, subprocess.CalledProcessError) else ""
            self.error = next((line.strip() for line in detail.splitlines() if line.strip()), "") or str(exc).splitlines()[0]

    def file_at(self, path: str, timestamp_ms: int) -> str | None:
        if self.error is not None:
            return None
        op = next((op for ms, op in self.ops if ms <= timestamp_ms), None)
        if op is None or self.repo is None:
            return None
        result = subprocess.run(
            ["jj", "--at-op", op, "--ignore-working-copy", "file", "show", "-r", "@", f"root-file:{json.dumps(path)}"],
            cwd=self.repo, capture_output=True, text=True, check=False,
        )
        return result.stdout if result.returncode == 0 else None


def skill_read_ok(events: list[dict], uri: str) -> bool:
    calls: set[str] = set()
    for item in events:
        event = item.get("event") or {}
        if item.get("type") != "event" or event.get("toolName") != "read":
            continue
        if event.get("type") == "tool_execution_start" and (event.get("args") or {}).get("path") == uri:
            calls.add(event.get("toolCallId"))
        elif event.get("type") == "tool_execution_end" and event.get("toolCallId") in calls and not event.get("isError"):
            return True
    return False


def workdir_for(trial_dir: Path) -> str:
    return "/workspace/" + trial_dir.name.split("__")[0]


def measure(trial_dir: Path) -> dict:
    events = load_events(trial_dir / "yacht-execution" / "events.jsonl")
    repo = trial_dir / "artifacts" / "repo"
    history = RepoHistory(repo if repo.is_dir() else None)
    workdir = workdir_for(trial_dir)
    seen: set[tuple[str, str]] = set()
    total = 0
    rows = []
    for index, stop in enumerate(stops(events), 1):
        lines = line_count(stop.text)
        total += lines
        files = []
        for turn in stop.turns:
            cue_lines = "\n".join(line for line in turn.text.splitlines() if CUE.search(line))
            if not cue_lines:
                continue
            for path in review_paths(cue_lines, workdir):
                content = history.file_at(path, turn.timestamp_ms)
                if content is None:
                    files.append({"path": path, "lines": 0, "counted": False, "missing": True})
                    continue
                key = (path, hashlib.sha256(content.encode()).hexdigest())
                counted = key not in seen
                seen.add(key)
                file_lines = line_count(content) if counted else 0
                total += file_lines
                files.append({"path": path, "lines": file_lines, "counted": counted})
        rows.append({"index": index, "timestamp_ms": stop.timestamp_ms, "lines": lines, "files": files})
    return {"olr": total, "stops": rows, "history_error": history.error}


def main(argv: list[str]) -> int:
    if not argv:
        print(__doc__, file=sys.stderr)
        return 2
    for arg in argv:
        trial = Path(arg)
        print(json.dumps({"trial": str(trial), **measure(trial)}))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
```

Run: `direnv exec . uv run --locked pytest evals/workflow-outcome/tests/test_wo_olr.py -q`
Expected: PASS (9 tests, including the multi-dot / one-letter-extension filename, per-message file version, and unreadable-history tests added in execution).

- [ ] **Step 3: Write the failing report test**

`$S/tests/test_wo_report.py`:

```python
import json
import sys
from pathlib import Path

SUITE = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(SUITE))
import report


def make_trial(logbook, run, vessel, task, reward, fraction, usage, seconds, read_brainstorming, stop_text, *, valid=True, reward_file=True, exception_info=None):
    trial = logbook / "runs" / run / "course-handoff" / "custom-eval" / "vessels" / vessel / "harbor-trials" / "harbor" / f"{task}__{vessel[:4]}{run[-1]}"
    (trial / "yacht-execution").mkdir(parents=True)
    (trial / "verifier").mkdir()
    events = [
        {"type": "event", "event": {"type": "message_end", "message": {"role": "user", "timestamp": 1, "content": [{"type": "text", "text": "idea"}]}}},
        {"type": "event", "event": {"type": "message_end", "message": {"role": "assistant", "timestamp": 2, "content": [{"type": "text", "text": stop_text}]}}},
    ]
    if read_brainstorming:
        events += [
            {"type": "event", "event": {"type": "tool_execution_start", "toolCallId": "c", "toolName": "read", "args": {"path": "skill://brainstorming"}}},
            {"type": "event", "event": {"type": "tool_execution_end", "toolCallId": "c", "toolName": "read", "isError": False}},
        ]
    (trial / "yacht-execution" / "events.jsonl").write_text("\n".join(json.dumps(e) for e in events) + "\n")
    summary = {} if usage is None else {"usage": usage}
    summary["valid"] = valid
    summary["ended"] = "natural"
    (trial / "yacht-execution" / "summary.json").write_text(json.dumps(summary))
    if reward_file:
        (trial / "verifier" / "reward.json").write_text(json.dumps({"reward": reward, "fraction": fraction}))
    result = {"started_at": "2026-10-12T10:00:00Z", "finished_at": f"2026-10-12T10:00:{seconds:02d}Z", "exception_info": exception_info}
    (trial / "result.json").write_text(json.dumps(result))
    return trial


def test_trials_are_found_with_their_measurements(tmp_path):
    make_trial(tmp_path, "run-001", "baseline", "tally", 0.0, 0.6, {"input_tokens": 100, "cache_read_tokens": 10, "output_tokens": 20}, 30, False, "done\nok")
    make_trial(tmp_path, "run-001", "sjujperpowers", "tally", 1.0, 1.0, {"input_tokens": 200, "cache_read_tokens": 40, "output_tokens": 50}, 50, True, "done")
    trials = {t.vessel: t for t in report.find_trials(tmp_path)}
    assert trials["baseline"].olr == 2
    assert trials["baseline"].setup_failure is False
    assert trials["sjujperpowers"].wall_seconds == 50
    assert trials["sjujperpowers"].run == "run-001"
    assert trials["sjujperpowers"].reward == 1.0

def test_null_finished_timestamp_keeps_trial_with_unknown_wall_time(tmp_path):
    make_trial(tmp_path, "run-001", "baseline", "tally", 1.0, 1.0, {"input_tokens": 100, "cache_read_tokens": 10, "output_tokens": 20}, 20, False, "done")
    result_path = next(tmp_path.rglob("result.json"))
    result_path.write_text(json.dumps({"started_at": "2026-10-12T10:00:00Z", "finished_at": None}))

    trials = report.find_trials(tmp_path)

    assert len(trials) == 1
    assert trials[0].wall_seconds is None
    assert "| baseline | tally | run-001 | 1.0 | 1.00 | 1 | 1 | 100/10/20 | - | no |" in report.render(trials)


def test_treatment_without_brainstorming_is_a_setup_failure_and_not_pooled(tmp_path):
    make_trial(tmp_path, "run-001", "sjujperpowers", "tally", 1.0, 1.0, {"input_tokens": 200, "cache_read_tokens": 40, "output_tokens": 50}, 40, True, "a")
    make_trial(tmp_path, "run-002", "sjujperpowers", "tally", 0.0, 0.0, {"input_tokens": 900, "cache_read_tokens": 0, "output_tokens": 9}, 59, False, "b")
    trials = report.find_trials(tmp_path)
    assert sorted(t.setup_failure for t in trials) == [False, True]
    text = report.render(trials)
    assert "| sjujperpowers | 1 | 1/1 | 1.00 | 1 [1–1] | 200 | 40 | 50 | 40 | 1 | 0 |" in text
    assert "| sjujperpowers | tally | run-002 | 0.0 | 0.00 | 1 | 1 | 900/0/9 | 59 | setup |" in text


def test_report_rows_per_arm(tmp_path):
    for run, reward, fraction, olr_text in (("run-001", 1.0, 1.0, "a"), ("run-002", 0.0, 0.5, "a\nb\nc")):
        make_trial(tmp_path, run, "baseline", "shelf", reward, fraction, {"input_tokens": 100, "cache_read_tokens": 10, "output_tokens": 20}, 20, False, olr_text)
    text = report.render(report.find_trials(tmp_path))
    assert "| baseline | 2 | 1/2 | 0.75 | 2 [1–3] | 100 | 10 | 20 | 20 | 0 | 0 |" in text


def test_missing_usage_is_left_out_of_arm_medians(tmp_path):
    make_trial(tmp_path, "run-001", "baseline", "shelf", 1.0, 1.0, {"input_tokens": 100, "cache_read_tokens": 10, "output_tokens": 20}, 20, False, "a")
    make_trial(tmp_path, "run-002", "baseline", "shelf", 1.0, 1.0, {"input_tokens": 300, "cache_read_tokens": 30, "output_tokens": 40}, 20, False, "a")
    make_trial(tmp_path, "run-003", "baseline", "shelf", 1.0, 1.0, None, 20, False, "a")
    text = report.render(report.find_trials(tmp_path))
    assert "| baseline | 3 | 3/3 | 1.00 | 1 [1–1] | 200 | 20 | 30 | 20 | 0 | 0 |" in text
    assert "| baseline | shelf | run-003 | 1.0 | 1.00 | 1 | 1 | - | 20 | no |" in text


def test_all_missing_usage_makes_arm_token_medians_unknown(tmp_path):
    make_trial(tmp_path, "run-001", "baseline", "shelf", 1.0, 1.0, None, 20, False, "a")
    make_trial(tmp_path, "run-002", "baseline", "shelf", 1.0, 1.0, None, 20, False, "a")
    text = report.render(report.find_trials(tmp_path))
    assert "| baseline | 2 | 2/2 | 1.00 | 1 [1–1] | - | - | - | 20 | 0 | 0 |" in text


def test_invalid_execution_is_excluded_and_counted(tmp_path):
    make_trial(tmp_path, "run-001", "baseline", "tally", 1.0, 1.0, {"input_tokens": 100, "cache_read_tokens": 10, "output_tokens": 20}, 30, False, "done", valid=False)
    make_trial(tmp_path, "run-002", "baseline", "tally", 0.0, 0.5, {"input_tokens": 300, "cache_read_tokens": 30, "output_tokens": 40}, 40, False, "a\nb")
    trials = report.find_trials(tmp_path)
    invalid = next(t for t in trials if t.run == "run-001")
    assert invalid.invalid == "invalid execution"
    assert invalid.olr == 1
    text = report.render(trials)
    assert "| baseline | 1 | 0/1 | 0.50 | 2 [2–2] | 300 | 30 | 40 | 40 | 0 | 1 |" in text
    assert "| baseline | tally | run-001 | 1.0 | 1.00 | 1 | 1 | 100/10/20 | 30 | invalid: invalid execution |" in text


def test_invalid_treatment_that_read_brainstorming_is_not_pooled(tmp_path):
    make_trial(tmp_path, "run-001", "sjujperpowers", "tally", 1.0, 1.0, {"input_tokens": 200, "cache_read_tokens": 40, "output_tokens": 50}, 40, True, "a", valid=False)
    trials = report.find_trials(tmp_path)
    assert trials[0].setup_failure is False
    assert trials[0].invalid == "invalid execution"
    text = report.render(trials)
    assert "| sjujperpowers | 0 | - | - | - | - | - | - | - | 0 | 1 |" in text
    assert "| sjujperpowers | tally | run-001 | 1.0 | 1.00 | 1 | 1 | 200/40/50 | 40 | invalid: invalid execution |" in text


def test_missing_reward_is_invalid_not_zero(tmp_path):
    make_trial(tmp_path, "run-001", "baseline", "shelf", 0.0, 0.0, {"input_tokens": 100, "cache_read_tokens": 10, "output_tokens": 20}, 20, False, "done", reward_file=False)
    trials = report.find_trials(tmp_path)
    assert trials[0].reward is None
    assert trials[0].invalid == "missing reward"
    text = report.render(trials)
    assert "| baseline | 0 | - | - | - | - | - | - | - | 0 | 1 |" in text
    assert "| baseline | shelf | run-001 | - | - | 1 | 1 | 100/10/20 | 20 | invalid: missing reward |" in text

def test_reward_without_fraction_is_invalid_and_does_not_break_the_report(tmp_path):
    trial = make_trial(tmp_path, "run-001", "baseline", "shelf", 1.0, 1.0, {"input_tokens": 100, "cache_read_tokens": 10, "output_tokens": 20}, 20, False, "done")
    (trial / "verifier" / "reward.json").write_text(json.dumps({"reward": 1.0}))
    make_trial(tmp_path, "run-002", "baseline", "shelf", 0.0, 0.5, {"input_tokens": 300, "cache_read_tokens": 30, "output_tokens": 40}, 20, False, "done")
    trials = sorted(report.find_trials(tmp_path), key=lambda t: t.run)
    assert [t.invalid for t in trials] == ["missing fraction", None]
    text = report.render(trials)
    assert "| baseline | 1 | 0/1 | 0.50 |" in text



def test_valid_trial_with_exception_and_reward_is_scored(tmp_path):
    make_trial(
        tmp_path, "run-001", "baseline", "tally", 0.0, 0.4,
        {"input_tokens": 100, "cache_read_tokens": 10, "output_tokens": 20}, 20, False, "done",
        exception_info={"exception_type": "AgentTimeoutError", "exception_message": "timed out"},
    )
    trials = report.find_trials(tmp_path)
    assert trials[0].invalid is None
    assert trials[0].reward == 0.0
    text = report.render(trials)
    assert "| baseline | 1 | 0/1 | 0.40 | 1 [1–1] | 100 | 10 | 20 | 20 | 0 | 0 |" in text
    assert "| baseline | tally | run-001 | 0.0 | 0.40 | 1 | 1 | 100/10/20 | 20 | no |" in text
```

Run: `direnv exec . uv run --locked pytest evals/workflow-outcome/tests/test_wo_report.py -q`
Expected: FAIL with `ModuleNotFoundError: No module named 'report'`.

- [ ] **Step 4: Write `report.py`**

`$S/report.py`:

```python
#!/usr/bin/env python3
"""Per-arm report for a workflow-outcome logbook.

Usage: report.py LOGBOOK
Setup failures (treatment trials with no successful skill://brainstorming read)
and infrastructure-invalid trials are listed but not pooled. A trial that is both
counts as invalid. A Harbor exception alone does not exclude a valid rewarded trial.
"""
from __future__ import annotations

import json
import statistics
import sys
from dataclasses import dataclass
from datetime import datetime
from pathlib import Path

import olr

BASELINE = "baseline"


@dataclass
class Trial:
    vessel: str
    task: str
    run: str
    reward: float | None
    fraction: float | None
    tokens: dict | None
    wall_seconds: float | None
    olr: int
    setup_failure: bool
    invalid: str | None
    history_error: str | None
    stops: list[dict]


def _json(path: Path) -> dict:
    return json.loads(path.read_text()) if path.is_file() else {}


def _seconds(result: dict) -> float | None:
    try:
        start = datetime.fromisoformat(result["started_at"])
        end = datetime.fromisoformat(result["finished_at"])
    except (KeyError, AttributeError, TypeError, ValueError):
        return None
    return (end - start).total_seconds()


def _number(value) -> float | None:
    if isinstance(value, bool) or not isinstance(value, (int, float)):
        return None
    return float(value)


def _invalid_reason(trial_dir: Path) -> str | None:
    summary_path = trial_dir / "yacht-execution" / "summary.json"
    if not summary_path.is_file():
        return "missing summary"
    summary = _json(summary_path)
    if summary.get("valid") is not True:
        return "invalid execution"
    reward = _json(trial_dir / "verifier" / "reward.json")
    if not (trial_dir / "verifier" / "reward.json").is_file() or _number(reward.get("reward")) is None:
        return "missing reward"
    if _number(reward.get("fraction")) is None:
        return "missing fraction"
    return None


def find_trials(logbook: Path) -> list[Trial]:
    trials = []
    for events_path in sorted(logbook.rglob("yacht-execution/events.jsonl")):
        trial_dir = events_path.parent.parent
        parts = trial_dir.parts
        if "vessels" not in parts:
            continue
        vessel = parts[parts.index("vessels") + 1]
        run = next((p for p in parts if p.startswith("run-")), "run-001")
        invalid = _invalid_reason(trial_dir)
        reward = _json(trial_dir / "verifier" / "reward.json")
        measured = olr.measure(trial_dir)
        events = olr.load_events(events_path)
        trials.append(
            Trial(
                vessel=vessel,
                task=trial_dir.name.split("__")[0],
                run=run,
                reward=_number(reward.get("reward")),
                fraction=_number(reward.get("fraction")),
                tokens=_tokens(_json(trial_dir / "yacht-execution" / "summary.json")),
                wall_seconds=_seconds(_json(trial_dir / "result.json")),
                olr=measured["olr"],
                setup_failure=vessel != BASELINE and not olr.skill_read_ok(events, "skill://brainstorming"),
                invalid=invalid,
                history_error=measured["history_error"],
                stops=measured["stops"],
            )
        )
    return trials


def _tokens(summary: dict) -> dict | None:
    usage = summary.get("usage")
    if not isinstance(usage, dict):
        return None
    keys = ("input_tokens", "cache_read_tokens", "output_tokens")
    if any(key not in usage for key in keys):
        return None
    return {
        "input": usage["input_tokens"],
        "cache_read": usage["cache_read_tokens"],
        "output": usage["output_tokens"],
    }


def _median_tokens(trials: list[Trial], key: str) -> str:
    values = [t.tokens[key] for t in trials if t.tokens is not None]
    return "-" if not values else f"{statistics.median(values):g}"


def _token_cell(tokens: dict | None) -> str:
    if tokens is None:
        return "-"
    return f"{tokens['input']}/{tokens['cache_read']}/{tokens['output']}"


def _excluded(trial: Trial) -> str:
    if trial.invalid:
        return f"invalid: {trial.invalid}"
    return "setup" if trial.setup_failure else "no"


def _score(value: float | None, digits: str) -> str:
    return "-" if value is None else format(value, digits)


def render(trials: list[Trial]) -> str:
    lines = [
        "| Arm | Trials | Resolved | Mean fraction | OLR median [range] | Median input tokens | Median cache-read tokens | Median output tokens | Median wall s | Setup failures | Invalid |",
        "|---|---|---|---|---|---|---|---|---|---|---|",
    ]
    for vessel in sorted({t.vessel for t in trials}):
        arm = [t for t in trials if t.vessel == vessel]
        pooled = [t for t in arm if not t.invalid and not t.setup_failure]
        failures = sum(1 for t in arm if t.setup_failure and not t.invalid)
        invalid = sum(1 for t in arm if t.invalid)
        if not pooled:
            lines.append(f"| {vessel} | 0 | - | - | - | - | - | - | - | {failures} | {invalid} |")
            continue
        olrs = [t.olr for t in pooled]
        walls = [t.wall_seconds for t in pooled if t.wall_seconds is not None]
        resolved = sum(1 for t in pooled if t.reward is not None and t.reward >= 1.0)
        wall = f"{statistics.median(walls):g}" if walls else "-"
        lines.append(
            f"| {vessel} | {len(pooled)} | {resolved}/{len(pooled)} | "
            f"{statistics.mean(t.fraction for t in pooled):.2f} | "
            f"{statistics.median(olrs):g} [{min(olrs)}–{max(olrs)}] | "
            f"{_median_tokens(pooled, 'input')} | {_median_tokens(pooled, 'cache_read')} | {_median_tokens(pooled, 'output')} | "
            f"{wall} | {failures} | {invalid} |"
        )
    lines.append("")
    for vessel in sorted({t.vessel for t in trials}):
        arm = [t for t in trials if t.vessel == vessel]
        missing = sum(1 for t in arm for s in t.stops for f in s["files"] if f.get("missing"))
        unreadable = sum(1 for t in arm if t.history_error)
        lines.append(f"Reviewed files not readable from the jj operation log ({vessel}): {missing}")
        lines.append(f"Trials with unreadable jj history ({vessel}): {unreadable}")
    lines += ["", "| Arm | Task | Run | Reward | Fraction | OLR | Stop lines (+file lines) | Tokens in/cache/out | Wall s | Excluded |", "|---|---|---|---|---|---|---|---|---|---|"]
    for t in sorted(trials, key=lambda t: (t.vessel, t.task, t.run)):
        per_stop = ", ".join(
            f"{s['lines']}" + (f"+{sum(f['lines'] for f in s['files'])}" if s["files"] else "") for s in t.stops
        )
        lines.append(
            f"| {t.vessel} | {t.task} | {t.run} | {_score(t.reward, '.1f')} | {_score(t.fraction, '.2f')} | {t.olr} | {per_stop} | "
            f"{_token_cell(t.tokens)} | {'-' if t.wall_seconds is None else f'{t.wall_seconds:g}'} | {_excluded(t)} |"
        )
    return "\n".join(lines) + "\n"


def main(argv: list[str]) -> int:
    if len(argv) != 1:
        print(__doc__, file=sys.stderr)
        return 2
    print(render(find_trials(Path(argv[0]))), end="")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
```

Run: `direnv exec . uv run --locked pytest evals/workflow-outcome/tests/test_wo_report.py -q`
Expected: PASS (11 tests, including the null-timestamp, token, and invalid-trial tests added in execution).

- [ ] **Step 5: Run all host tests and lint**

Run: `direnv exec . uv run --locked pytest evals/workflow-outcome/tests -q && direnv exec . uv run --locked ruff check evals/workflow-outcome`
Expected: PASS (47 tests: the verifier temp-dir, token, OLR-version, unreadable-history and invalid-trial tests added, the two `sjp-modes` tests removed, in execution); ruff reports no errors (fix any it reports in the new files only).

- [ ] **Step 6: Commit**

```bash
jj commit evals/workflow-outcome/olr.py evals/workflow-outcome/report.py evals/workflow-outcome/tests/test_wo_olr.py evals/workflow-outcome/tests/test_wo_report.py -m "Add OLR measurement and per-arm report for workflow-outcome"
```

### Task 6: Images, zero-cost verifier proof, and the task spec

**Files:**
- Create: `$S/Task.md`
- Modify: `README.md` (eval table)

**Interfaces:**
- Consumes: task directories (Tasks 1–3), regattas (Task 4).
- Produces: local images `yacht/harbor-launcher:workflow-outcome` and `yacht-evals/workflow-outcome-{tally,shelf,slugs}:v1`, with image IDs recorded in `Task.md`.

- [ ] **Step 1: Ask for build approval**

Stop and ask the operator: "Approve local rootless builds of four images (Harbor launcher from yacht `2d4407cd`, and three task images from `evals/workflow-outcome/tasks/*/environment`)?" Check headroom first and include it in the question: `df -h / /srv` (stop if root has under 50 GiB free). Do not build without a yes in the conversation.

- [ ] **Step 2: Build the launcher from the pinned Yacht revision**

```bash
export DOCKER_HOST=unix:///run/user/1100/docker.sock
STAGE=/srv/agent-dev/worktrees/wo-build-staging  # on /srv, not root's /tmp
rm -rf "$STAGE" && mkdir -p "$STAGE/yacht-2d4407cd"
git -C /srv/agent-dev/projects/yacht archive 2d4407cdfe802868fec2f220cdb5959649a7de84 | tar -x -C "$STAGE/yacht-2d4407cd"
uv run --project /srv/agent-dev/projects/yacht --frozen --no-sync \
  python "$STAGE/yacht-2d4407cd/containers/harbor-launcher/prepare_context.py" --output "$STAGE/wo-launcher-context"
# The managed proxy intercepts TLS; the launcher Dockerfile takes its CA as a build-only secret.
docker build --secret id=build_ca,src=/var/lib/agent-github-policy/ca-bundle.crt \
  -f "$STAGE/wo-launcher-context/Dockerfile" -t yacht/harbor-launcher:workflow-outcome "$STAGE/wo-launcher-context"
docker image inspect --format '{{.Id}}' yacht/harbor-launcher:workflow-outcome
```

Expected: the build succeeds and prints one `sha256:` image ID. Record it.

- [ ] **Step 3: Build the task images**

```bash
export DOCKER_HOST=unix:///run/user/1100/docker.sock
for t in tally shelf slugs; do
  docker build -t "yacht-evals/workflow-outcome-$t:v1" "evals/workflow-outcome/tasks/$t/environment" &&
  docker image inspect --format "$t {{.Id}}" "yacht-evals/workflow-outcome-$t:v1"
done
```

Expected: three builds succeed; `jj --version` prints `jj 0.41.0` during each build; three image IDs print. Record them.

- [ ] **Step 4: Prove each verifier in its image at zero model cost**

```bash
export DOCKER_HOST=unix:///run/user/1100/docker.sock
for t in tally shelf slugs; do
  docker run --rm \
    -v "$PWD/evals/workflow-outcome/tasks/$t/tests:/tests:ro" \
    -v "$PWD/evals/workflow-outcome/tasks/$t/solution:/solution:ro" \
    "yacht-evals/workflow-outcome-$t:v1" bash -c '
      bash /tests/test.sh && echo "empty $(cat /logs/verifier/reward.json)" &&
      (cd /workspace/'"$t"' && python3 -m pytest -q -p no:cacheprovider >/dev/null && echo visible-ok) &&
      bash /solution/solve.sh >/dev/null && bash /tests/test.sh && echo "solved $(cat /logs/verifier/reward.json)"'
done
```

Expected, for each task: `empty {"reward": 0.0, "fraction": <below 1>}`, `visible-ok`, `solved {"reward": 1.0, "fraction": 1.0000}`.

- [ ] **Step 5: Confirm no hidden material is in the images**

```bash
export DOCKER_HOST=unix:///run/user/1100/docker.sock
for t in tally shelf slugs; do
  docker run --rm "yacht-evals/workflow-outcome-$t:v1" bash -c \
    'find / -xdev \( -name "check_*.py" -o -name solve.sh -o -name Task.md -o -name test.sh \) 2>/dev/null; jj -R /workspace/'"$t"' log -r main --no-graph -T "description"'
done
```

Expected: no paths printed; each prints `Initial project`.

- [ ] **Step 6: Write `Task.md` and the README row**

`$S/Task.md` (fill the four `sha256:` values from Steps 2–3; they are the only values not known when this plan was written):

```markdown
# Task: workflow-outcome

**Status:** Built and verifier-proven; smoke run not yet approved.
**Outcome:** plane:SJUP-2
**Spec:** sjujperpowers `docs/project/specs/2026-10-06-workflow-outcome-eval-design.md`

Do not copy or mount this file, hidden checks (`tests/hidden/`), or solutions into an evaluated agent's workspace or image.

## Question

Does the Sjujperpowers workflow land better code from a rough idea than the same agent without it, and how many lines does the operator read to get it (OLR)?

## Arms

| Vessel | Riggings |
|---|---|
| `baseline` | `subscription-sol` |
| `sjujperpowers` | `subscription-sol`, `sjujperpowers` (skills from commit in `riggings/sjujperpowers/PINNED_COMMIT`, plus the `~/.omp/agent/AGENTS.md` bootstrap: chmod skill scripts, then `using-sjujperpowers`) |

Model `omp-subscriptions/openai-codex/gpt-6.1-sol:medium` (declared in `riggings/models.yml`, context window 500000), OMP `18.2.6`, retained mode, eight follow-ups `Approved. Continue as the brief says.`, 200 turns per message, 1800 s per message, 5400 s per trial.

## Images (local, rootless, not published)

| Image | ID |
|---|---|
| `yacht/harbor-launcher:workflow-outcome` (yacht `2d4407cd`) | `sha256:…` |
| `yacht-evals/workflow-outcome-tally:v1` | `sha256:…` |
| `yacht-evals/workflow-outcome-shelf:v1` | `sha256:…` |
| `yacht-evals/workflow-outcome-slugs:v1` | `sha256:…` |

Before any run, `docker image inspect --format '{{.Id}}'` must match this table.

## Scoring

- `reward` 1.0 only when every hidden check passes on the final local `main` (git-moved `main` counts); `fraction` = share passed. Not on `main` = 0.
- OLR from `olr.py`: non-blank lines of each stop plus each repository file a stop asks the operator to review, once per file version (version = `@` at the last jj operation before the stop). Reviewed files absent from the jj operation log are reported as missing per arm.
- Usage is Yacht's per-trial token counts (input, cache read, output); dollar cost is not reported because the subscription models carry no prices.
- A treatment trial with no successful `skill://brainstorming` read is a setup failure, reported separately.

## Gates

Each requires the operator's approval in conversation, with a spending cap for inference:

1. Smoke: `regattas/workflow-outcome-smoke.toml`, one repetition (2 trials).
2. Scored: `regattas/workflow-outcome.toml`, `--repetitions 3` (18 trials), only after every smoke validity check passes.

## Run

    export DOCKER_HOST=unix:///run/user/1100/docker.sock
    REGATTA=evals/workflow-outcome/regattas/<smoke-or-scored>.toml
    LOGBOOK=$PWD/logbooks/workflow-outcome-<smoke|scored>-$(date -u +%Y%m%dT%H%M%SZ)  # absolute: Yacht runs each vessel from its report dir
    secretspec run --file /srv/agent-dev/projects/yacht/secretspec.toml \
      --provider omp-subscriptions --scope openai \
      --reason "Run the approved workflow-outcome Yacht evaluation" \
      -- uv run --locked yacht run "$REGATTA" --logbook "$LOGBOOK" \
         --secret openai=@env:OPENAI_API_KEY [--repetitions 3]
    uv run --locked python evals/workflow-outcome/report.py "$LOGBOOK"
    uv run --locked yacht report "$LOGBOOK"
```

In `README.md`, add one row to the eval table (after the release-plan retention row):

```markdown
| Does the Sjujperpowers workflow land better code with less operator reading? | [Workflow outcome](evals/workflow-outcome/Task.md) | `plane:SJUP-2` |
```

- [ ] **Step 7: Commit**

```bash
jj commit evals/workflow-outcome/Task.md README.md -m "Record workflow-outcome images and task spec"
```

### Task 7: Smoke run and validity checks

**Files:**
- Modify: `$S/Task.md` (status, smoke result, final limits)
- Modify (only if the smoke run requires it): `$S/tasks/*/task.toml` execution limits

**Interfaces:**
- Consumes: everything above; `olr.py`, `report.py`.

- [ ] **Step 1: Ask for smoke approval**

Stop and ask the operator for approval and a spending cap for the smoke run (2 trials, `tally` only, both arms, up to 90 minutes each). Do not launch without both.

- [ ] **Step 2: Check image IDs, then launch the smoke run**

```bash
export DOCKER_HOST=unix:///run/user/1100/docker.sock
for i in yacht/harbor-launcher:workflow-outcome yacht-evals/workflow-outcome-tally:v1; do docker image inspect --format "$i {{.Id}}" "$i"; done
REGATTA=evals/workflow-outcome/regattas/workflow-outcome-smoke.toml
LOGBOOK=$PWD/logbooks/workflow-outcome-smoke-$(date -u +%Y%m%dT%H%M%SZ)  # absolute: Yacht runs each vessel from its report dir
secretspec run --file /srv/agent-dev/projects/yacht/secretspec.toml \
  --provider omp-subscriptions --scope openai \
  --reason "Run the approved workflow-outcome smoke evaluation" \
  -- direnv exec . uv run --locked yacht run "$REGATTA" --logbook "$LOGBOOK" \
     --secret openai=@env:OPENAI_API_KEY
```

Expected: the IDs match `Task.md`; the run completes with two trials. Run it with `timeout: 0` (it can take three hours).

- [ ] **Step 3: Run each validity check from the spec**

Set `B` and `T` to the baseline and treatment trial directories (`find "$LOGBOOK" -type d -path '*vessels/baseline/harbor-trials/harbor/tally__*'`, likewise `vessels/sjujperpowers`).

```bash
# 1. Skill reads: treatment true/true, baseline false/false; baseline system prompt lists no Sjujperpowers skill.
direnv exec . uv run --locked python - "$B" "$T" <<'PY'
import sys
from pathlib import Path
sys.path.insert(0, "evals/workflow-outcome")
import olr
for trial in sys.argv[1:]:
    events = olr.load_events(Path(trial) / "yacht-execution" / "events.jsonl")
    print(trial.split("/vessels/")[1].split("/")[0],
          olr.skill_read_ok(events, "skill://using-sjujperpowers"),
          olr.skill_read_ok(events, "skill://brainstorming"))
PY
jq -r 'select(.type=="context") | .context.systemPrompt | join("\n")' "$B/yacht-execution/events.jsonl" | grep -c -E 'using-sjujperpowers|brainstorming' || true

# 2. Treatment scripts: no permission errors, and a current ledger row.
jq -r 'select(.type=="event" and .event.type=="tool_execution_end" and .event.toolName=="bash") | .event.result.content[]?.text // empty' "$T/yacht-execution/events.jsonl" | grep -i -E 'permission denied' || echo "no permission errors"
jq -c 'select(.type=="event" and .event.type=="tool_execution_start" and .event.toolName=="bash") | .event.args.command' "$T/yacht-execution/events.jsonl" | grep -E 'fresh-change|trunk-rev|classify-risk|verdict' | head
cat "$T/artifacts/repo/.sjujperpowers/verdicts.jsonl"
jj -R "$T/artifacts/repo" --ignore-working-copy log -r main --no-graph -T 'commit_id ++ "\n"'

# 3. Verifier: already proven in Task 6 Step 4 (solve.sh -> 1.0, empty -> 0.0); confirm both trials wrote reward.json.
cat "$B/verifier/reward.json" "$T/verifier/reward.json"

# 4. OLR per stop, to compare against a hand count.
direnv exec . uv run --locked python evals/workflow-outcome/olr.py "$B" "$T"

# 5. Context tokens at the final assistant message (compaction is disabled; window is 500000).
for d in "$B" "$T"; do jq -c 'select(.type=="event" and .event.type=="message_end" and .event.message.role=="assistant") | .event.message.usage | .input + .cacheRead + .cacheWrite' "$d/yacht-execution/events.jsonl" | tail -1; done
```

Expected:
1. Treatment `True True`, baseline `False False`, and the grep count `0`.
2. `no permission errors`; the bash commands include `fresh-change` and `classify-risk.mjs`/`verdict.mjs`; `verdicts.jsonl` has a row whose `commit` is the treatment's final `main` commit ID or an ancestor of it on the landed stack.
3. Two `reward.json` files with `reward` and `fraction`.
4. Hand-count each stop's non-blank lines and each reviewed file's non-blank lines in one trial per arm from `events.jsonl` and `artifacts/repo`; the counts must equal the script's.
5. Two integers; record them in `Task.md`. A value near 500000 means the trial ended on context exhaustion: report it as an outcome, and if the treatment ends there before landing, raise it with the operator before the scored run.

If `artifacts/repo` lacks `.jj` (Harbor did not copy hidden directories), stop: OLR file versions cannot be resolved. Report the gap to the operator, not a workaround.

If any check fails, record which and why in `Task.md`, fix the cause in this suite (never in the skills or Yacht), get a new smoke approval, and rerun. A trial that hit a limit is a valid result, not a failure; if both hit the 5400 s trial limit before landing, propose new limits to the operator before the scored run and apply them identically to all three `task.toml` files.

- [ ] **Step 4: Record the smoke result**

In `$S/Task.md`, set `**Status:**` to `Smoke run passed all validity checks (<logbook name>); scored run not yet approved.` and add a `## Smoke result` section with the `report.py` output, the final-stop context tokens per arm, and the final execution limits.

- [ ] **Step 5: Commit**

```bash
jj commit evals/workflow-outcome -m "Record workflow-outcome smoke result"
```

### Task 8: Scored run and report

**Files:**
- Create: `$S/FINDINGS.md`
- Modify: `$S/Task.md` (status)

**Interfaces:**
- Consumes: `report.py`, Yacht's `yacht report`.

- [ ] **Step 1: Ask for scored-run approval**

Stop and ask the operator for approval and a spending cap for 18 trials (three tasks × three repetitions × two arms). State the smoke trials' token usage per trial as the basis.

- [ ] **Step 2: Check image IDs and launch**

```bash
export DOCKER_HOST=unix:///run/user/1100/docker.sock
for i in yacht/harbor-launcher:workflow-outcome yacht-evals/workflow-outcome-{tally,shelf,slugs}:v1; do docker image inspect --format "$i {{.Id}}" "$i"; done
REGATTA=evals/workflow-outcome/regattas/workflow-outcome.toml
LOGBOOK=$PWD/logbooks/workflow-outcome-scored-$(date -u +%Y%m%dT%H%M%SZ)  # absolute: Yacht runs each vessel from its report dir
secretspec run --file /srv/agent-dev/projects/yacht/secretspec.toml \
  --provider omp-subscriptions --scope openai \
  --reason "Run the approved workflow-outcome scored evaluation" \
  -- direnv exec . uv run --locked yacht run "$REGATTA" --logbook "$LOGBOOK" \
     --secret openai=@env:OPENAI_API_KEY --repetitions 3
```

Expected: IDs match `Task.md`; 18 trials complete. Run with `timeout: 0`.

- [ ] **Step 3: Produce both reports**

```bash
direnv exec . uv run --locked python evals/workflow-outcome/report.py "$LOGBOOK" > /tmp/wo-report.md
direnv exec . uv run --locked yacht report "$LOGBOOK"
```

- [ ] **Step 4: Write `FINDINGS.md`**

`$S/FINDINGS.md` contains, in this order:
1. Run identity: logbook name, Sjujperpowers commit from `PINNED_COMMIT`, image IDs, model, limits, date.
2. The `report.py` tables verbatim (per-arm summary, per-trial rows with per-stop OLR breakdown).
3. Yacht's paired comparison across repetitions from `yacht report`, with its variance note, labelled as unfiltered: it pools treatment setup failures, which `report.py` excludes. If any setup failure occurred, say which pairs it affects and do not read the paired result as a workflow result.
4. A plain statement of whether nine trials per arm separate the arms on resolved rate, mean `fraction`, and OLR, or not; "the sample cannot separate the arms" when they overlap.
5. The spec's limitations, restated: unconditional approvals, OMP's todo reminder (with, per treatment trial, whether any file edit or commit happened between a stop that asks for approval and the next operator message), one model and harness, no verify skill or high tier, no subagents (SDD and multi-model review unmeasured), the treatment `AGENTS.md` bootstrap (chmod + using-sjujperpowers), usage reported as tokens, not dollars.

- [ ] **Step 5: Commit and report to Plane**

```bash
jj commit evals/workflow-outcome/FINDINGS.md evals/workflow-outcome/Task.md -m "Record workflow-outcome scored results"
```

Set `Task.md` status to `Scored run complete (<logbook name>); see FINDINGS.md.` before committing. Then post a comment on Plane `SJUP-2` with the per-arm summary table, the separation statement, and the path `yacht-evals/evals/workflow-outcome/FINDINGS.md`.
