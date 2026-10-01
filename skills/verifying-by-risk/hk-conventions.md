# hk Conventions

Reference for projects whose checks run through [hk](https://hk.jdx.dev). Sjujperpowers skills call these entry points; projects own the configuration.

## Layout

- `hk.pkl` at the repository root amends a base: `amends ".hk/base/rust.pkl"`. Projects add or override steps there.
- `.hk/base/<language>.pkl` is copied from the nix-config template and amends the hk Config package of the same version as the binary.
- `nix/hk.nix` packages the upstream release binary; `devenv.nix` adds `(import ./nix/hk.nix { inherit pkgs; })` to `packages`.
- `bash scripts/update-hk [vX.Y.Z]` re-pins the binary hashes and every Config package version together. Upgrading means running it and committing the result, not `devenv update`.

## Profiles

- hk has no `fast` profile. Steps with no `profiles` always run; they are the default set and hold static checks only (formatters in check mode, linters).
- Profiles are additive opt-ins, enabled with `--profile NAME`, `HK_PROFILE=NAME`, or `--slow`. Nothing enables `ci` automatically, not even `CI=true`. A step runs only when **all** of its positive profiles are enabled, so a step meant for either `slow` or `ci` is declared twice: once with `List("slow")` and once with `List("ci", "!slow")`.
- Tests run once per verification, as `risk.toml`'s `test` command. Do not also run them through the default set.

## Entry points

- Jujutsu never fires git hooks. Skills call `hk check --all` explicitly, through `verifying-by-risk`'s `scripts/hk-check`; `hk install` is not part of the workflow.
- hk takes configuration from places no diff shows. The first of `hk.local.pkl`, `.config/hk.local.pkl`, `hk.pkl`, `.config/hk.pkl` found wins, and local files are usually git-ignored, so Jujutsu never snapshots them. `skip_steps`, `skip_hooks`, and `exclude` also merge from `HK_*` variables, git config, and `~/.config/hk/config.pkl`. `scripts/hk-check` pins `HK_FILE` to the root `hk.pkl`, clears `HK_*`, uses an empty user config directory, hides `~/.gitconfig` and system git config, and refuses when the effective configuration still skips steps, skips hooks, or excludes files, naming each source (`hk config explain`). That covers the repository's git config and `$XDG_CONFIG_HOME/git/config`, which it cannot hide. `hk.skipHooks=check` is the case to remember: `hk check --all` exits 0 and the plan still lists every step as included. Keep the project's config in the root `hk.pkl`.
- `hk check --all` exits non-zero on any failing step. It also checks untracked, non-ignored files. A missing tool fails too, so run it inside the project's dev shell (after `direnv`, or `just dev <skill dir>/scripts/hk-check`).
- `hk check --step NAME` with a name that matches no step exits 0. To prove a specific step failed, read its `step_completed` event from `--format jsonl`.
- The template defines only the `check` hook, so `hk fix` errors. Format with the project's own recipe (`just fmt`).

## Protected paths

`verifying-by-risk` treats these as protected in every project, whether or not `.sjujperpowers/risk.toml` exists:

- `hk.pkl`, `.config/hk.pkl`, `.hk/**`, `nix/hk.nix`, `scripts/update-hk`
- `.sjujperpowers/risk.toml`
- `.agents/skills/verify-*/SKILL.md`, `.agents/skills/verify-*/features/**`, `.agents/skills/verify-*/scripts/**`, and the `.claude/skills/verify-*` links to them
- `.github/workflows/**`
- `devenv.nix`, `devenv.yaml`, `devenv.lock`

Any stack touching one needs explicit operator approval naming the path before it lands, whatever its tier.

The built-ins cover hk's own configuration. They do not cover what the declared checks read: a `justfile` recipe that hk steps or `test` call, linter and formatter config (`clippy.toml`, `rustfmt.toml`, `.cargo/config.toml`, `rust-toolchain.toml`, `deny.toml`), or a `Cargo.toml` that declares `[lints]`. List those in `risk.toml`'s `protected` when you write it: protect whatever the declared checks read, so a change cannot weaken a check without the operator naming the file.

## `.sjujperpowers/risk.toml`

```toml
version = 1
default = "medium"          # tier for paths no rule matches
test = "just test"          # the unit-test command every verification runs
protected = [               # added to the built-in protected paths
  "migrations/**",
]

[[rule]]                    # first matching rule wins for a path
paths = ["docs/**", "*.md"]
tier = "low"

[[rule]]
paths = ["src/auth/**"]
tier = "high"
```

Supported syntax: comments, basic double-quoted strings, string arrays (single- or multi-line, trailing comma allowed), the top-level keys `version`, `default`, `test`, and `protected`, and `[[rule]]` tables with exactly `paths` and `tier`. Anything else is a parse error, and a parse error makes the stack `high`. Without `test`, no verdict can grade above `type-check-only`.

Globs are matched against the full repository-relative path. `*` and `?` stay within one path segment, `**/` matches zero or more directories, and `dir/**` matches everything under `dir`.

## Follow-up

A changed-files adapter (`hk check --from-ref/--to-ref` over Jujutsu revision ranges, NUL-delimited, rename- and delete-aware) is not built yet. Until it is, use `--all`.
