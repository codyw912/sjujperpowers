# Validation Baseline Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use sjujperpowers:subagent-driven-development (recommended) or sjujperpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give sjujperpowers one declared, deterministic test command (`devenv shell scripts/test`) that passes on trunk, a dev environment providing every tool it needs, and a `risk.toml` that declares it.

**Architecture:** `scripts/test` discovers `tests/*/test-*.{sh,mjs}`, leaves out a named exclusion list, and fails on any non-zero exit or skip line. A hand-written devenv (`devenv.nix`, `devenv.yaml`, `nix/hk.nix`) supplies Node 22, graphviz, tmux, shellcheck, shfmt, jq, git, and hk 2.4.0; jj stays the host's. `.sjujperpowers/risk.toml` declares the command, tiers, and protected paths. `scripts/fork-rename.mjs` learns to keep the upstream evals repository name so its test passes on trunk.

**Tech Stack:** Bash; Node.js 22 (`node:test`); devenv 2.3.1 with nixpkgs pinned to `8ce4ef6cb6f871616146b9fe26d2a5ae594e94fe`; hk 2.4.0 (musl release); Jujutsu 0.41 (host).

**Spec:** `docs/project/specs/2026-10-14-validation-baseline-design.md`

**Source:** linear:CEW-224

## Global Constraints

- The declared test command is exactly `devenv shell scripts/test`.
- A test passes only when it exits 0 and prints no line matching `^[[:space:]]*(\[SKIP\]|SKIP:)`. A `.mjs` file also fails when its output matches `^# +(\[SKIP\]|SKIP:)` or `^# (skipped|todo) [1-9]` (Node's TAP-wrapped markers, and a non-zero `# skipped` or `# todo` count).
- Exclusions are exactly the six files in the spec's Test runner section; an exclusion naming a missing file fails the run.
- jj is not in the dev environment; `scripts/test` exits 1 before running anything when `jj --version` does not succeed.
- hk is 2.4.0, from `https://github.com/jdx/hk/releases/download/v2.4.0/hk-x86_64-unknown-linux-musl.tar.gz`, hash `sha256-80WYZxykC+XDCDJKYO8wtzbbu/QlnftRGr15AJ7k3io=`; x86_64-linux only.
- No `hk.pkl`, `.hk/`, `scripts/update-hk`, verify skill, or CI.
- Never write the upstream project name as a bare literal in a new or edited file; use `<upstream>`, `$UP`, or `${up}`.
- New shell files pass `shellcheck -s bash --severity=warning`.
- `.devenv*` and `.direnv/` are ignored before the first `devenv shell` in the repository, so jj never snapshots them.
- Every check removes the temp directories it creates.
- Commit by fileset (`jj commit <paths> -m …`); never a bare `jj commit`.
- Protected paths in this stack (`devenv.nix`, `devenv.yaml`, `devenv.lock`, `nix/hk.nix`, `.sjujperpowers/risk.toml`) need the operator to name them before landing.

## File Structure

| Path | Responsibility |
|---|---|
| `scripts/fork-rename.mjs` | Keeps `obra/<upstream>` and `<upstream>-evals` attributions |
| `tests/fork-rename/test-fork-rename.sh` | Asserts the evals attribution is kept; repository guard copies tracked files only |
| `docs/project/plans/2026-10-12-workflow-outcome-eval.md` | Line 28 reworded |
| `scripts/test` | The declared test runner |
| `devenv.nix`, `devenv.yaml`, `devenv.lock`, `.envrc` | Dev environment |
| `nix/hk.nix` | Pinned hk 2.4.0 |
| `.gitignore` | Ignores devenv and direnv state |
| `docs/testing.md` | How to run the suite |
| `.sjujperpowers/risk.toml` | Risk policy declaring `test` |

---

### Task 1: fork-rename keeps the upstream evals attribution

**Files:**
- Modify: `scripts/fork-rename.mjs:4-6,16,35`
- Modify: `tests/fork-rename/test-fork-rename.sh:23,35-37,45,47`
- Modify: `docs/project/plans/2026-10-12-workflow-outcome-eval.md:28`

**Interfaces:**
- Consumes: nothing.
- Produces: `tests/fork-rename/test-fork-rename.sh` exits 0 on trunk, which Task 2's runner needs.

- [ ] **Step 1: Write the failing test**

In `tests/fork-rename/test-fork-rename.sh`, replace line 23 with:

```bash
printf 'Use %s: see https://github.com/obra/%s/issues/571 and [%s-evals](https://github.com/prime-radiant-inc/%s-evals) %s %s\n' "$UP" "$UP" "$UP" "$UP" "${UP^}" "${UP^^}" > "$fixture/skills/using-$UP/SKILL.md"
```

Replace lines 35-37 with:

```bash
assert_eq "$(cat "$fixture/skills/using-sjujperpowers/SKILL.md")" \
  "Use sjujperpowers: see https://github.com/obra/$UP/issues/571 and [$UP-evals](https://github.com/prime-radiant-inc/$UP-evals) Sjujperpowers SJUJPERPOWERS" \
  "all three capitalisations rewritten, attribution URLs and the evals repository name preserved"
```

Replace line 47 (the working-tree `tar`) with a copy of tracked files only:

```bash
(cd "$REPO_ROOT" && jj file list | tar -cf - -T -) | (cd "$copy" && tar -xf -)
```

and change the comment on line 45 to:

```bash
# Guard against the literal creeping back in — on a copy of the tracked files,
# so the test never mutates the repo and ignored scratch files cannot fail it.
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash tests/fork-rename/test-fork-rename.sh`
Expected: FAIL on "all three capitalisations rewritten, attribution URLs and the evals repository name preserved" (the evals name is rewritten to `sjujperpowers-evals`) and on "repo tree is already fully renamed" (`rewrote 6 files`).

- [ ] **Step 3: Write minimal implementation**

In `scripts/fork-rename.mjs`, replace comment lines 4-6 with:

```js
// directory names. Idempotent, and it leaves upstream attributions alone:
// URLs under github.com/obra/<upstream>/ and the <upstream>-evals repository
// name. The upstream name is assembled at runtime so this file never
// contains it and cannot rewrite itself.
```

Replace the line ``const keep = `obra/${up}`;`` with:

```js
const keepRe = new RegExp(`(${[`obra/${up}`, `${up}-evals`].join("|")})`);
```

Replace the line that starts `const t = s.split(keep)` with:

```js
  const t = s.split(keepRe).map((seg, i) => (i % 2 ? seg : pairs.reduce((acc, [a, b]) => acc.replaceAll(a, b), seg))).join("");
```

`split` with one capturing group puts each kept match at an odd index, so kept text is never rewritten and `join("")` restores it.

- [ ] **Step 4: Run test to verify the fixture passes and the guard still names the plan**

Run: `bash tests/fork-rename/test-fork-rename.sh`
Expected: the fixture assertions PASS; "repo tree is already fully renamed" still FAILS with `rewrote 1 files` (the plan line).

- [ ] **Step 5: Reword the plan line**

In `docs/project/plans/2026-10-12-workflow-outcome-eval.md` line 28, replace ``yacht-evals's own `docs/<upstream>` tracking`` (the backticked path names the upstream project) with `yacht-evals's own tracking docs`. The line then ends: "nothing is added to yacht-evals's own tracking docs."

- [ ] **Step 6: Run test to verify it passes**

Run: `bash tests/fork-rename/test-fork-rename.sh`
Expected: `STATUS: PASSED`.

Also confirm the script on the real tree is a no-op on a copy:

```bash
T=$(mktemp -d) && jj file list | tar -cf - -T - | tar -xf - -C "$T" && (cd "$T" && node scripts/fork-rename.mjs); rm -rf "$T"
```

Expected: `fork-rename: rewrote 0 files, moved 0 paths`.

- [ ] **Step 7: Commit**

```bash
jj commit scripts/fork-rename.mjs tests/fork-rename/test-fork-rename.sh docs/project/plans/2026-10-12-workflow-outcome-eval.md -m "Keep the upstream evals attribution in fork-rename"
```

---

### Task 2: Dev environment and the declared test runner

**Files:**
- Create: `scripts/test` (mode 755)
- Create: `nix/hk.nix`, `devenv.nix`, `devenv.yaml`, `.envrc`
- Create (generated): `devenv.lock`
- Modify: `.gitignore`
- Modify: `docs/testing.md:20,21,26,29`

**Interfaces:**
- Consumes: Task 1 (fork-rename passes).
- Produces: `devenv shell scripts/test` exits 0 on this stack with `29/29 passed`; Task 3 declares exactly that command.

- [ ] **Step 1: Ignore devenv state first**

Append to `.gitignore`:

```gitignore

# devenv / direnv
.devenv*
.direnv/
devenv.local.nix
devenv.local.yaml
```

Run: `jj st` — Expected: `.gitignore` modified, nothing under `.devenv`.

- [ ] **Step 2: Write `nix/hk.nix`**

```nix
# hk pinned per project (skills/verifying-by-risk/hk-conventions.md). The tests
# amend hk@2.4.0's Config package, so the binary must be 2.4.0 too.
{ pkgs }:
let
  version = "2.4.0";
  sources = {
    x86_64-linux = {
      url = "https://github.com/jdx/hk/releases/download/v${version}/hk-x86_64-unknown-linux-musl.tar.gz";
      hash = "sha256-80WYZxykC+XDCDJKYO8wtzbbu/QlnftRGr15AJ7k3io=";
    };
  };
  system = pkgs.stdenv.hostPlatform.system;
  source = sources.${system} or (throw "nix/hk.nix: no hk ${version} binary is pinned for ${system}");
in
pkgs.stdenvNoCC.mkDerivation {
  pname = "hk";
  inherit version;
  src = pkgs.fetchurl source;
  sourceRoot = ".";
  installPhase = "install -Dm755 hk $out/bin/hk";
}
```

- [ ] **Step 3: Write `devenv.yaml`, `devenv.nix`, `.envrc`**

`devenv.yaml`:

```yaml
# yaml-language-server: $schema=https://devenv.sh/devenv.schema.json
inputs:
  devenv:
    url: github:cachix/devenv/v2.3.1?dir=src/modules
  nixpkgs:
    url: github:NixOS/nixpkgs/8ce4ef6cb6f871616146b9fe26d2a5ae594e94fe
```

`devenv.nix`:

```nix
{ pkgs, ... }:

{
  # Every tool the declared test command (`devenv shell scripts/test`) needs.
  # jj is deliberately absent: the tests run the host's jj against this
  # checkout, and a newer client could write data the host's jj cannot read.
  packages = with pkgs; [
    nodejs_22
    git
    jq
    shellcheck
    shfmt
    graphviz
    tmux
    (import ./nix/hk.nix { inherit pkgs; })
  ];
}
```

`.envrc`:

```bash
#!/usr/bin/env bash

eval "$(devenv direnvrc)"
use devenv
```

- [ ] **Step 4: Build the environment and check its tools**

Run: `devenv shell -- bash -c 'hk --version; node --version; dot -V 2>&1; tmux -V; command -v jj'`
Expected: `hk 2.4.0`, `v22.23.2`, a graphviz version line, a tmux version, and jj at `/run/current-system/sw/bin/jj` (host). `devenv.lock` now exists; `jj st` shows no `.devenv` paths.

- [ ] **Step 5: Write `scripts/test`**

```bash
#!/usr/bin/env bash
# The declared deterministic test command (`test` in .sjujperpowers/risk.toml).
# Runs every tests/*/test-*.sh with bash and every tests/*/test-*.mjs with
# `node --test`, except the files in EXCLUDED. A test passes only when it exits
# 0 and prints no skip line: a skip means a missing tool, not a pass.
# Run it inside the dev environment: `devenv shell scripts/test`.
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT" || exit 1

EXCLUDED=(
  # Drives `claude -p`.
  tests/claude-code/test-subagent-driven-development.sh
  # Drives `claude -p`.
  tests/claude-code/test-subagent-driven-development-integration.sh
  # Drives `opencode run` when OpenCode is installed.
  tests/opencode/test-priority.sh
  # Drives `opencode run` when OpenCode is installed.
  tests/opencode/test-tools.sh
  # Sourced by the claude-code tests; not a test.
  tests/claude-code/test-helpers.sh
  # Called with arguments by test-bootstrap-caching.sh; not a node:test file.
  tests/opencode/test-bootstrap-caching.mjs
)
SKIP_LINE='^[[:space:]]*(\[SKIP\]|SKIP:)'

jj --version >/dev/null 2>&1 || {
  echo "scripts/test: jj is not on PATH or does not run; the tests need the host's jj" >&2
  exit 1
}

for path in "${EXCLUDED[@]}"; do
  [[ -f "$path" ]] || {
    echo "scripts/test: excluded file $path does not exist; update EXCLUDED" >&2
    exit 1
  }
done

is_excluded() {
  local path
  for path in "${EXCLUDED[@]}"; do
    [[ "$1" == "$path" ]] && return 0
  done
  return 1
}

shopt -s nullglob
found=()
for t in tests/*/test-*.sh tests/*/test-*.mjs; do
  is_excluded "$t" || found+=("$t")
done
if [[ "${#found[@]}" -eq 0 ]]; then
  echo "scripts/test: no tests found under tests/" >&2
  exit 1
fi
mapfile -t tests < <(printf '%s\n' "${found[@]}" | sort)

log="$(mktemp)"
trap 'rm -f "$log"' EXIT
passed=0
for t in "${tests[@]}"; do
  case "$t" in
    *.mjs) node --test "$t" >"$log" 2>&1 </dev/null ;;
    *) bash "$t" >"$log" 2>&1 </dev/null ;;
  esac
  status=$?
  if [[ "$status" -ne 0 ]]; then
    echo "FAIL $t (exit $status)"
  elif grep -Eq "$SKIP_LINE" "$log"; then
    echo "SKIP $t"
  else
    echo "ok   $t"
    passed=$((passed + 1))
    continue
  fi
  tail -n 20 "$log" | sed 's/^/     /'
done

echo "$passed/${#tests[@]} passed"
[[ "$passed" -eq "${#tests[@]}" ]]
```

Run: `chmod 755 scripts/test && shellcheck -s bash --severity=warning scripts/test`
Expected: no output, exit 0.

- [ ] **Step 6: Prove the runner fails where it must (throwaway, outside the repository)**

```bash
F=$(mktemp -d) && mkdir -p "$F/scripts" "$F/tests/claude-code" "$F/tests/opencode" "$F/tests/a" \
  && cp scripts/test "$F/scripts/test" \
  && touch "$F"/tests/claude-code/test-subagent-driven-development.sh "$F"/tests/claude-code/test-subagent-driven-development-integration.sh \
           "$F"/tests/claude-code/test-helpers.sh "$F"/tests/opencode/test-priority.sh "$F"/tests/opencode/test-tools.sh "$F"/tests/opencode/test-bootstrap-caching.mjs \
  && printf 'exit 0\n' > "$F/tests/a/test-ok.sh" \
  && printf 'exit 3\n' > "$F/tests/a/test-fail.sh" \
  && printf 'echo "SKIP: hk not installed"\n' > "$F/tests/a/test-skip.sh" \
  && printf 'echo "  [SKIP] scenario: hk not on PATH"\n' > "$F/tests/a/test-bracket.sh" \
  && printf "import test from 'node:test';\ntest('ok', () => {});\n" > "$F/tests/a/test-ok.mjs"
"$F/scripts/test"; echo "rc=$?"
rm "$F/tests/opencode/test-tools.sh"; "$F/scripts/test"; echo "rc=$?"
mkdir -p "$F/fake" && printf '#!/bin/sh\nexit 127\n' > "$F/fake/jj" && chmod +x "$F/fake/jj"
env PATH="$F/fake:$PATH" "$F/scripts/test"; echo "rc=$?"
rm -rf "$F"
```

Expected, in order:
1. `ok   tests/a/test-ok.mjs`, `ok   tests/a/test-ok.sh`, `FAIL tests/a/test-fail.sh (exit 3)`, `SKIP tests/a/test-skip.sh`, `SKIP tests/a/test-bracket.sh` (in sorted order), then `2/5 passed`, `rc=1`.
2. `scripts/test: excluded file tests/opencode/test-tools.sh does not exist; update EXCLUDED`, `rc=1`.
3. `scripts/test: jj is not on PATH or does not run; the tests need the host's jj`, `rc=1`. (A fake `jj` that exits 127 shadows the real one; stripping `PATH` instead also removes `bash` and `dirname` on NixOS.)

Then prove the hk skip is caught on the real suite: hk is not on the host, so outside the dev shell the hk tests skip:

Run: `scripts/test; echo "rc=$?"`
Expected: `SKIP tests/verifying-by-risk/test-hk-check.sh` and `SKIP tests/evals/test-scenario-discrimination.sh` among the lines, `rc=1`.

- [ ] **Step 7: Run the declared command**

Run: `devenv shell scripts/test; echo "rc=$?"`
Expected: 29 `ok` lines, `29/29 passed`, `rc=0`.

- [ ] **Step 8: Update `docs/testing.md`**

Line 20: replace `(requires `hk`; skips without it)` with `(requires hk 2.4.0, which the dev environment provides)`.

Line 21: replace `(requires `tmux`; skips without it)` with `(requires `tmux`, which the dev environment provides)`.

Line 26: replace `the hk-dependent cases need hk 2.4.0 on PATH and print SKIP without it` with `the hk-dependent cases need hk 2.4.0, which the dev environment provides`.

Replace line 29 with:

```markdown
Run every deterministic test with `scripts/test` inside the dev environment: `direnv allow` once, or `devenv shell scripts/test`. That command is `test` in `.sjujperpowers/risk.toml`, so verifying-by-risk runs exactly it. The runner discovers `tests/*/test-*.sh` and `tests/*/test-*.mjs`, leaves out the files in its `EXCLUDED` list (tests that drive `claude -p` or `opencode run`, and two helpers), and fails a test that exits non-zero or prints a skip line: a skip means a missing tool. jj comes from the host, not the dev environment. The first hk test run downloads hk's Config package from GitHub. The LLM suites (`tests/explicit-skill-requests/`, the `run-*.sh` runners) and `evals/` stay hand-run.
```

- [ ] **Step 9: Commit**

```bash
jj commit .gitignore nix/hk.nix devenv.nix devenv.yaml devenv.lock .envrc scripts/test docs/testing.md -m "Declare a dev environment and a deterministic test runner"
```

Run: `jj st` — Expected: the working copy has no changes.

---

### Task 3: Risk policy

**Files:**
- Create: `.sjujperpowers/risk.toml`

**Interfaces:**
- Consumes: Task 2's command string `devenv shell scripts/test`.
- Produces: trunk policy for every later stack.

- [ ] **Step 1: Write the policy**

`.sjujperpowers/risk.toml`:

```toml
version = 1
default = "medium"
test = "devenv shell scripts/test"
protected = [
  "scripts/test",
  ".omp/extensions/**",
  ".pi/extensions/**",
  ".opencode/plugins/**",
  "hooks/**",
  ".claude-plugin/**",
  ".codex-plugin/**",
]

[[rule]]
paths = ["skills/**/SKILL.md", "skills/**/scripts/**"]
tier = "high"

[[rule]]
paths = ["evals/**"]
tier = "medium"

[[rule]]
paths = ["docs/**", "*.md"]
tier = "low"
```

- [ ] **Step 2: Prove classification against it (throwaway repository)**

```bash
SKILL=$PWD/skills/verifying-by-risk/scripts/classify-risk.mjs
R=$(mktemp -d) && mkdir -p "$R/.sjujperpowers" && cp .sjujperpowers/risk.toml "$R/.sjujperpowers/" \
  && (cd "$R" && jj git init --colocate >/dev/null 2>&1 && echo base > README.md && jj commit -m base >/dev/null && jj bookmark create main -r @- >/dev/null)
probe() { # <path> -> tier protected testCommand
  (cd "$R" && jj new main -m probe >/dev/null && mkdir -p "$(dirname "$1")" && echo x > "$1" \
    && node "$SKILL" --repo "$R" | jq -r '"\(.tier) \(.protected) \(.testCommand)"')
}
for p in docs/a.md NOTES.md skills/a/SKILL.md skills/a/scripts/x.mjs skills/a/reference.md evals/x/story.md scripts/test hooks/session-start .pi/extensions/x.ts lib/other.js; do
  printf '%-24s %s\n' "$p" "$(probe "$p")"
done
rm -rf "$R"
```

Expected:

```text
docs/a.md                low false devenv shell scripts/test
NOTES.md                 low false devenv shell scripts/test
skills/a/SKILL.md        high false devenv shell scripts/test
skills/a/scripts/x.mjs   high false devenv shell scripts/test
skills/a/reference.md    medium false devenv shell scripts/test
evals/x/story.md         medium false devenv shell scripts/test
scripts/test             medium true devenv shell scripts/test
hooks/session-start      medium true devenv shell scripts/test
.pi/extensions/x.ts      medium true devenv shell scripts/test
lib/other.js             medium false devenv shell scripts/test
```

- [ ] **Step 3: Commit**

```bash
jj commit .sjujperpowers/risk.toml -m "Declare the risk policy and test command"
```

- [ ] **Step 4: Run the suite once more at the head**

Run: `devenv shell scripts/test; echo "rc=$?"`
Expected: `29/29 passed`, `rc=0`.
