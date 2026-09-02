---
name: executing-plans
description: Use when you have a written implementation plan to execute in a separate session with review checkpoints
---

# Executing Plans

## Overview

Load plan, review critically, execute all tasks, report when complete.

**Announce at start:** "I'm using the executing-plans skill to implement this plan."

**Note:** Tell your human partner that Sjujperpowers works much better with access to subagents (Claude Code, Codex, OpenCode, Pi, and Oh My Pi all qualify; see the per-platform tool refs in `../using-sjujperpowers/references/`). If subagents are available, use sjujperpowers:subagent-driven-development instead of this skill.

## The Process

### Step 1: Load and Review Plan

1. Read the plan file and approved spec before repository mutation.
2. Use sjujperpowers:tracking-providers and retain the normalized provider selection plus materialized Kata parent/child refs.
3. With Kata, select the lowest-numbered open child in this plan's retained mapping. Start on a fresh change with sjujperpowers:starting-a-change and supply that exact ref; never use project-wide ready ordering for a named plan. Without Kata, start on a fresh change normally.
4. Review critically; identify any questions or concerns.
5. If concerns: raise them with your human partner before starting. For a claimed Kata child, add a substantive comment describing the blocker.
6. If no concerns: create harness-native todos for every plan task and proceed. Todos remain mandatory under every execution provider.

### Step 2: Execute Tasks

For each task:

1. Mark its harness todo `in_progress`.
2. With Kata, use the materialized child matching the plan task number. The first child was claimed by starting-a-change. Before any code mutation for each later child, repeat the checked preflight, run `kata --project <project> --json claim <ref>` without `--force`, describe the fresh Jujutsu change with `Kata: <project>#<short_id>`, and comment with the stable Jujutsu change ID. Claim conflict stops that task.
3. Follow every plan step and commit boundary exactly.
4. Run the task's verification.
5. With Kata, add a substantive comment naming the verified scope, exact test command, result, and Jujutsu change ID. Do not close: landing/publication has not happened.
6. Mark the harness todo completed and continue to the next task on the fresh `@` created by `jj commit`.

If a task blocks, keep its todo actionable, add the Kata `blocked` label with a substantive comment, and stop. On deliberate resume, reconcile the issue and todo first and remove `blocked` only after the blocker is resolved.

### Step 3: Complete Development

After all tasks are implemented and verified:

- Keep the Kata parent and children open.
- Announce: "I'm using the finishing-a-change-stack skill to complete this work."
- **REQUIRED SUB-SKILL:** Use sjujperpowers:finishing-a-change-stack.
- Hand it the plan path and retained Kata refs, then follow that skill to verify, shape, present options, execute the choice, and close only after the configured completion event.

## When to Stop and Ask for Help

**STOP executing immediately when:**
- Hit a blocker (missing dependency, test fails, instruction unclear)
- Plan has critical gaps preventing starting
- You don't understand an instruction
- Verification fails repeatedly

**Ask for clarification rather than guessing.**

## When to Revisit Earlier Steps

**Return to Review (Step 1) when:**
- Partner updates the plan based on your feedback
- Fundamental approach needs rethinking

**Don't force through blockers** - stop and ask.

## Remember
- Review plan critically first
- Follow plan steps exactly
- Don't skip verifications
- Reference skills when plan says to
- Stop when blocked, don't guess
- Never build inside a change that already holds someone else's undescribed work
