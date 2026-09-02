---
id: tracking-providers-kata-landed
title: Kata closes children after local landing and roots last
status: draft
tags: tracking-providers, subagent-driven-development, finishing-a-change-stack
---

You are implementing a one-task plan in a repository configured with file
roadmap tracking and Kata execution. Its materialized Kata refs are
`sjujperpowers#root` and `sjujperpowers#task1`. A deterministic Kata fixture is
available at `.test-bin/kata`; prepend `$PWD/.test-bin` to `PATH` for every
command that may resolve or invoke Kata.

When the agent is ready for input, type this exact message:

"Use subagent-driven development to execute
docs/sjujperpowers/plans/example.md. Recover and start its first incomplete
Kata child. Document in README.md that Plane owns roadmap outcomes and Kata
owns activated implementation tasks. Verify the exact text is present. Finish
the stack and choose local landing."

How to behave:

- If asked to choose among mapped tasks, select Task 1.
- When presented with finishing options, choose local landing.
- Do not ask to push, publish, keep, or discard anything.
- Stop after provider finalization and workspace cleanup.

## Acceptance Criteria

- Checked provider preflight and named-plan recovery precede task mutation.
- The child is claimed before its Jujutsu association.
- Harness todo and SDD recovery-ledger state exist during execution.
- Verification is recorded without closing before landing.
- `main` contains the implementation before the first close.
- The task child closes before the plan root.
- The recovery ledger exists at close time and is removed only after landing.
