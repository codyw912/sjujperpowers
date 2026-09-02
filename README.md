# sjujperpowers

A personal fork of [obra/superpowers](https://github.com/obra/superpowers) that (1) is Jujutsu-native — skills speak `jj` only, work happens on fresh changes on `trunk()`, change IDs are the unit of record, landing is a bookmark move or `jj git push`; (2) supports independent roadmap and execution providers while preserving the existing file-roadmap/session defaults; (3) supports only Claude Code, Oh My Pi, Pi, Codex, and OpenCode; (4) drops the browser-based visual brainstorming companion.

## How it works

It starts from the moment you fire up your coding agent. As soon as it sees that you're building something, it *doesn't* just jump into writing code. It steps back and asks what you're really trying to do.

Once it's teased a spec out of the conversation, it shows it to you in chunks short enough to actually read.

After you've signed off on the design, your agent puts together an implementation plan that's clear enough for an enthusiastic junior engineer with poor taste, no judgement, no project context, and an aversion to testing to follow. It emphasizes true red/green TDD, YAGNI, and DRY.

When you say "go", it launches subagent-driven-development: agents work through each task, inspect and review, and continue. It's not uncommon for your agent to work autonomously for a couple hours without deviating from the plan.

Because the skills trigger automatically, you don't need to do anything special.

## Installation

Installation differs by harness. If you use more than one, install Sjujperpowers separately for each one.

### Claude Code

- Register the marketplace:

  ```
  /plugin marketplace add codyw912/sjujperpowers
  ```

- Install the plugin:

  ```
  /plugin install sjujperpowers@sjujperpowers-dev
  ```

### Codex (App and CLI)

This repo is its own Codex marketplace (`.agents/plugins/marketplace.json`), so no listing on the official marketplace is needed:

```bash
codex plugin marketplace add codyw912/sjujperpowers   # or a local checkout path
codex plugin add sjujperpowers@sjujperpowers-dev
```

Inside a Codex session the same two steps are `/plugin marketplace add codyw912/sjujperpowers` and `/plugin install sjujperpowers@sjujperpowers-dev`. Update with `codex plugin marketplace upgrade`.

### OpenCode

- Tell OpenCode:

  ```
  Fetch and follow instructions from https://raw.githubusercontent.com/codyw912/sjujperpowers/refs/heads/main/.opencode/INSTALL.md
  ```

- Detailed docs: [docs/README.opencode.md](docs/README.opencode.md)

### Pi and Oh My Pi

Install Sjujperpowers as a Pi package from this repository:

```bash
pi install git:github.com/codyw912/sjujperpowers
```

For local development, run Pi with this checkout loaded as a temporary package:

```bash
pi -e /path/to/sjujperpowers
```

The Pi package loads the Sjujperpowers skills and a small extension that injects the `using-sjujperpowers` bootstrap at session startup and again after compaction. Pi has native skills, so no compatibility `Skill` tool is required. Subagent and task-list tools remain optional Pi companion packages.

Oh My Pi loads `skill://<name>` from SKILL.md natively, so no bootstrap hook is required — installing the package still makes the skills discoverable.

## The workflow

1. **tracking-providers** (`sjujperpowers:tracking-providers`) — Resolve repository-local provider policy and preflight selected execution services.
2. **roadmapping** (`sjujperpowers:roadmapping`) — Capture an outcome in a file roadmap, reference an external Plane work item, or skip durable roadmap state.
3. **brainstorming** (`sjujperpowers:brainstorming`) — Refine the outcome into a versioned spec.
4. **writing-plans** (`sjujperpowers:writing-plans`) — Break the spec into numbered tasks. A Kata-backed plan materializes a non-executable plan root plus one executable child per task.
5. **starting-a-change** (`sjujperpowers:starting-a-change`) — Claim a configured Kata child, when applicable, then isolate work on a fresh change on `trunk()`.
6. **executing-plans** (`sjujperpowers:executing-plans`) or **subagent-driven-development** (`sjujperpowers:subagent-driven-development`) — Execute inline in batches, or dispatch a fresh subagent per task with two-stage review.
7. **finishing-a-change-stack** (`sjujperpowers:finishing-a-change-stack`) — Land the stack, then finalize local execution state at the configured completion milestone.

Always-on: **test-driven-development**, **systematic-debugging**, **verification-before-completion**, **requesting-code-review**, **receiving-code-review**.

The agent checks for relevant skills before any task.

## Tracking providers

Provider policy lives in `.sjujperpowers/config.json`. The end-to-end ownership flow is:

```text
Plane outcome -> versioned spec -> versioned plan -> Kata issues
-> Jujutsu changes/evidence -> curated Plane roll-up
```

The roadmap and execution slots are independent: `file + kata` and `plane + session` are valid. Without configuration, the explicit equivalent is:

```json
{
  "version": 1,
  "roadmap": { "provider": "file" },
  "execution": { "provider": "session" }
}
```

A Plane roadmap with Kata execution:

```json
{
  "version": 1,
  "roadmap": {
    "provider": "plane",
    "project": "Example Product"
  },
  "execution": {
    "provider": "kata",
    "project": "example-product",
    "completion": "landed"
  }
}
```

A repository with both durable provider slots disabled:

```json
{
  "version": 1,
  "roadmap": { "provider": "none" },
  "execution": { "provider": "none" }
}
```

Supported roadmap providers are `file`, `plane`, and `none`; execution providers are `session`, `kata`, and `none`. Kata is optional. When selected, its executable, daemon, and project must pass preflight before any issue or repository mutation.

Use one Plane workspace as the portfolio boundary and projects as product or repository ownership boundaries. On Community Edition, use modules for focused initiatives and linked work items in each participating project for cross-project efforts. Plane owns outcomes and priorities; Sjujperpowers only renders curated roll-ups, never silent remote mutations.

Use one Kata project per repository. Kata owns activated implementation tasks and evidence. A terminal multiplexer or workspace manager only groups user-interface sessions; a Jujutsu workspace is a separate working copy for a concurrent code change. They are not interchangeable.

Kata-backed plans label roots and executable children separately, and children block root completion. See the [provider design](docs/sjujperpowers/specs/2026-09-02-pluggable-tracking-providers-design.md) and [`tracking-providers` skill](skills/tracking-providers/SKILL.md) for the lifecycle and failure contracts.

## What's inside

- **using-sjujperpowers** — Bootstrap that makes the other skills fire
- **tracking-providers** — Repository-local roadmap and execution provider policy
- **roadmapping** — Long-term milestones that specs and plans reference
- **brainstorming** — Socratic design refinement
- **writing-plans** — Detailed implementation plans
- **starting-a-change** — Isolated work on a fresh change on `trunk()`
- **executing-plans** — Batch execution with checkpoints
- **subagent-driven-development** — Fast iteration with two-stage review
- **finishing-a-change-stack** — Land the stack
- **requesting-code-review** — Pre-review checklist
- **receiving-code-review** — Responding to feedback
- **test-driven-development** — RED-GREEN-REFACTOR cycle
- **systematic-debugging** — 4-phase root cause process
- **verification-before-completion** — Ensure it's actually fixed
- **dispatching-parallel-agents** — Concurrent subagent workflows
- **writing-skills** — Create and test new skills

## Credits

sjujperpowers is a personal fork of [obra/superpowers](https://github.com/obra/superpowers) by Jesse Vincent / Prime Radiant, released under the MIT License. See LICENSE.
