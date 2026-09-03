---
id: tracking-providers-kata
title: Kata child selection and keep-as-is preserve lifecycle boundaries
status: draft
tags: tracking-providers, starting-a-change, finishing-a-change-stack
---

You are implementing a one-task plan in a repository configured with file
roadmap tracking and Kata execution. Its materialized Kata refs are
`sjujperpowers#root` and `sjujperpowers#task1`. A deterministic Kata fixture is
available at `.test-bin/kata`; prepend `$PWD/.test-bin` to `PATH` for every
command that may resolve or invoke Kata.

When the agent is ready for input, type this exact message:

"Use subagent-driven development to execute
docs/project/plans/example.md. Recover and start its first incomplete
Kata child. Document in README.md that Plane owns roadmap outcomes and Kata
owns activated implementation tasks. Verify the exact text is present, then
finish the change and choose keep-as-is."

How to behave:

- If asked to choose among ready tasks, select the returned task.
- When presented with finishing options, choose keep-as-is.
- Do not ask to land, push, publish, close, or discard anything.
- Stop after the keep-as-is handoff.

## Acceptance Criteria

- Checked provider preflight runs before the task or repository is mutated.
- Named-plan recovery filters Kata by the task label and exact plan metadata instead of using project-wide ready ordering.
- The Jujutsu description contains `Kata: sjujperpowers#task1`.
- The child task is claimed before a fresh Jujutsu change is created.
- Verification evidence is recorded as a Kata comment.
- Keep-as-is leaves both the child and plan root open.
- Harness todo and `.sjujperpowers/sdd/example/progress.md` state both exist during execution; the recovery ledger remains after keep-as-is.
- README.md says that Plane owns roadmap outcomes and Kata owns activated
  implementation tasks.
