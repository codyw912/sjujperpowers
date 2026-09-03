# Kata Reference Pilot Design

**Outcome:** plane:SJUP-1

## Goal

Prove that a Plane-backed outcome can activate a versioned plan into Kata, carry one task through a Jujutsu change, and close only after local landing.

## Acceptance

- The plan materializes one Kata plan root and one task child.
- The task is claimed before its Jujutsu change is described.
- Verification evidence is recorded while the task remains open.
- The task closes only after its implementation lands on the local `main` bookmark.
