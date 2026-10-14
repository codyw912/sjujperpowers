# Rulings: 2026-10-14-validation-baseline

- | Spec vs plan | spec says jj guard "when jj is not on PATH"; plan uses `jj --version` (also catches a broken jj) | Ruling: plan's `jj --version` check stands — it is stricter than and implies the spec's — cost if wrong: none |
- | Spec vs plan | spec .envrc says `use devenv`; plan adds `eval "$(devenv direnvrc)"` first | Ruling: plan stands; devenv 2.x needs the direnvrc eval for `use devenv` (dev-init template) — cost if wrong: one line |
- Ruling: F1 add python3, which, perl, util-linux to devenv.nix — confirmed tests/codex/test-marketplace-manifest.sh:8 (python3), tests/verifying-by-risk/test-classify-risk.mjs:68 (which), tests/evals/test-scenario-discrimination.sh:429 (perl, setsid) resolve to /run/current-system/sw/bin inside the shell; spec says the environment provides every tool except jj — cost if wrong: four packages.
- Ruling: F2 skip detection also matches Node's TAP-wrapped form (`# SKIP:` / `#   [SKIP]`, confirmed with node 22) and fails a .mjs file whose summary reports `# skipped N` or `# todo N` with N > 0 — spec D2's intent is "no quiet skip"; no current .mjs test skips (all report skipped 0 / todo 0) — cost if wrong: a stricter runner.
- Ruling: F3 add .envrc to risk.toml protected — it is the direnv entrypoint for the declared environment; hk-conventions says protect what the checks read — cost if wrong: one extra approval.
- Ruling: spec sections (Development environment packages, D2/Test runner skip rule, Risk policy block) and plan Global Constraints are updated in the same fix change so the binding text matches the code — cost if wrong: none.

## Over fix-round budget

None.
