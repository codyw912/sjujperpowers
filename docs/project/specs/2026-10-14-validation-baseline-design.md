# Validation Baseline Design

**Outcome:** linear:CEW-224

## Summary

Give sjujperpowers one committed test command, a development environment that provides every tool that command needs, and a risk policy that declares the command. Once these land, a stack in this repository can grade `unit-tested`, not just `type-check-only`, and `test-fork-rename.sh` passes on trunk.

This is step 1 and step 2 of CEW-226. Its verify skill (step 3) is CEW-227, and hk static checks are out of scope (operator choice, 2026-10-14).

## Decisions

- **D1: Discovery runner, with a fixed exclusion list.** `scripts/test` runs every `tests/*/test-*.sh` with bash and every `tests/*/test-*.mjs` with `node --test`. A test added later runs without anyone editing a list. The script names the files it leaves out, with a reason for each. The operator chose this over a fixed list of tests and over an `npm test` script.
- **D2: A skip is a failure.** A test that prints a skip line (`SKIP:` or `[SKIP]` at the start of a line, after optional whitespace) fails the run even when it exits 0. For `.mjs` files the same markers also count after Node's TAP `#` prefix (`# SKIP:`, `#   [SKIP]`), and a summary line `# skipped N` or `# todo N` with N greater than 0 counts too: `test.skip` and `{ todo: true }` exit 0. Several tests skip quietly when a tool is missing, and a quiet skip is the gap this change closes.
- **D3: The declared command brings its own environment.** `risk.toml` sets `test = "devenv shell scripts/test"`. `devenv shell CMD` runs the command in the project environment and returns its exit status (checked with devenv 2.3.1: exit 7 returned 7, exit 0 returned 0). The command works with or without direnv.
- **D4: A hand-written devenv.** `dev-init auto` picks the Bun and prettier `typescript` template because of `package.json`, which does not fit a Node and Bash repository with no bundler. `devenv.nix`, `devenv.yaml`, and `.envrc` are written by hand, as CEW-226's operator comment asks.
- **D5: hk is pinned per project.** `nix/hk.nix` builds hk 2.4.0 from the upstream musl release, following hk-conventions' layout, and `devenv.nix` imports it. The tests pin `hk@2.4.0`'s Config package, and nixpkgs has only 2.0.1. `scripts/update-hk` and `.hk/base/` are not added: the repository has no `hk.pkl` whose Config version they would keep in step, and their template belongs to CEW-225.
- **D6: The risk policy follows CEW-226 step 2.** One addition: `scripts/test` is protected, because it is what the declared test runs, and that includes its exclusion list. `.envrc` is protected too: it is the direnv entrypoint for the declared environment. The `.pi/extensions/**` and `.opencode/plugins/**` harness entry points are protected too, like `.omp/extensions/**` (approved with the design).
- **D7: Fix fork-rename at its cause.** The script keeps upstream attribution for `obra/<upstream>` only, so it rewrites the real `prime-radiant-inc/<upstream>-evals` links to a repository that does not exist. The script learns to keep the `<upstream>-evals` name as well. The test copies only the files jj tracks, not the working tree.

## Test runner

`scripts/test` is Bash and runs from the repository root, wherever it is called from.

- **Discovery:** `tests/*/test-*.sh` and `tests/*/test-*.mjs`, sorted, one directory level deep (the current layout).
- **Exclusions,** each with a one-line reason in the script:
  - `tests/claude-code/test-subagent-driven-development.sh` and `tests/claude-code/test-subagent-driven-development-integration.sh`: they drive `claude -p`;
  - `tests/opencode/test-priority.sh` and `tests/opencode/test-tools.sh`: they drive `opencode run` when OpenCode is installed;
  - `tests/claude-code/test-helpers.sh`: sourced by other tests, not a test;
  - `tests/opencode/test-bootstrap-caching.mjs`: a helper that `test-bootstrap-caching.sh` calls with arguments, not a `node:test` file.
- **An exclusion that matches no file fails the run,** so a renamed test cannot slip out of both lists.
- **Per test:** run it, capture its output, and pass when it exits 0 with no skip line. For `.mjs` files a TAP-wrapped marker (`# SKIP:` or `#   [SKIP]`) and a summary line `# skipped N` or `# todo N` with N greater than 0 also count as skips. Print `ok   <path>`, or `FAIL <path> (exit <n>)` or `SKIP <path>`, followed by the last 20 lines of its output.
- **Summary:** `<passed>/<total> passed`. Exit 0 only when every test passed; otherwise exit 1.
- **Not run:** `tests/explicit-skill-requests/`, the `run-*.sh` harness runners, and the `evals/` scenarios. They need a live agent and stay hand-run.

## Development environment

- `devenv.yaml` pins nixpkgs to one commit, using the same input as the host's other devenv projects.
- `devenv.nix` packages: `nodejs_22`, `git`, `jq`, `shellcheck`, `shfmt`, `graphviz`, `tmux`, `python3`, `which`, `perl`, `util-linux` (for `setsid`), and hk from `nix/hk.nix`. Graphviz stays in the environment even though the host now has `dot`, because the environment, not the host, is what the declared check relies on. The four added packages are the same: tests run `python3`, `which`, `perl`, and `setsid`.
- jj is not in the environment. It is the repository's own version-control client, a prerequisite before any skill runs, and some tests run it against this checkout. The pinned nixpkgs ships jj 0.45.1 while the host has 0.41.0, and a newer client writing to this repository risks leaving data the host client cannot read. `scripts/test` fails at the start, before running any test, when `jj` is not on `PATH`.
- `nix/hk.nix`: `stdenvNoCC.mkDerivation` over `fetchurl` of `hk-x86_64-unknown-linux-musl.tar.gz` v2.4.0 with hash `sha256-80WYZxykC+XDCDJKYO8wtzbbu/QlnftRGr15AJ7k3io=`, the expression proven in `docs/project/plans/2026-10-01-verification-feedback-loop.md`. It is x86_64-linux only; other systems fail evaluation with a message naming the missing platform.
- `.envrc`: `use devenv`.
- `.gitignore` gains `.devenv*` and `.direnv/`. `devenv.lock` is committed.

## Risk policy

`.sjujperpowers/risk.toml`:

```toml
version = 1
default = "medium"
test = "devenv shell scripts/test"
protected = [
  "scripts/test",
  ".envrc",
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

The rules are listed in that order, and the first match wins. `*.md` matches top-level files only. Other files under `skills/`, such as prompt templates and reference files, fall to the `medium` default, as CEW-226 step 2 has it. `devenv.nix`, `devenv.yaml`, `devenv.lock`, `nix/hk.nix`, and `risk.toml` itself are protected by the built-ins.

## fork-rename fix

- `scripts/fork-rename.mjs` keeps two upstream names untouched: `obra/<upstream>` (as now) and `<upstream>-evals`. Both are attributions to repositories that exist upstream. The kept names are assembled at runtime, as `up` is now, so the script never carries the literal.
- `tests/fork-rename/test-fork-rename.sh`:
  - The fixture gains a `prime-radiant-inc/<upstream>-evals` link, and the test asserts that it is preserved.
  - The repository-tree guard copies `jj file list` output instead of tarring the working tree, so ignored scratch files under `.sjujperpowers/sdd/` cannot fail it.
- `docs/project/plans/2026-10-12-workflow-outcome-eval.md:28` names yacht-evals's own `docs/<upstream>` directory. That line is reworded ("yacht-evals's own tracking docs") rather than giving the script a third exception for one historical sentence.

## Documentation

- `docs/testing.md` replaces "Run plugin tests via the relevant directory's `run-*.sh` or `npm test`" with `scripts/test` (inside the dev shell, or `devenv shell scripts/test`). It also lists the exclusions by name and explains that a skip fails the run.
- The `tests/verifying-by-risk/`, `tests/creating-a-verification-skill/`, and `tests/evals/` entries in `docs/testing.md` say the tests skip without hk or tmux. They now say the dev environment provides the tool and that `scripts/test` fails on a skip.

## Verification

- `devenv shell scripts/test` exits 0 on the final stack, and its output has no skip line. That includes `test-hk-check.sh` and the discrimination test's hk cases running for real.
- **RED for the runner:**
  - with hk removed from `PATH` inside the shell (`devenv shell -- env PATH=<without hk> scripts/test`), the run fails and names the skipping tests;
  - a temporary failing `tests/zz/test-fail.sh` fails the run;
  - a temporary exclusion naming a missing file fails the run.
  - Each is a throwaway check outside the committed tree.
- **fork-rename:** RED first. The new attribution assertion fails against the current script, then passes after the fix.
- **Policy:** `classify-risk.mjs` on a throwaway repository with this `risk.toml` on its trunk reports `testCommand` as `devenv shell scripts/test`. A stack touching `scripts/test` reports `protected: true`, and a stack touching only `docs/` reports `tier: low`.

## Known limits

- The first hk test run downloads the `hk@2.4.0` Config package from GitHub. Later runs read it from `~/.cache/hk`. It is not vendored.
- `nix/hk.nix` covers x86_64-linux only.
- This stack still grades at most `type-check-only`: policy comes from trunk, and trunk has no `risk.toml` until this lands. The first stack after it can reach `unit-tested`.
- `behavior-tested` and above still need the verify skill (CEW-227).

## Non-goals

- hk static checks (`hk.pkl`), and fixing the shellcheck findings in `scripts/lint-shell.sh --all`.
- `scripts/update-hk`, `.hk/base/`, and a Node devenv template (CEW-225).
- A `verify-sjujperpowers` skill (CEW-227).
- CI.
