# sjujperpowers

A personal fork of [obra/superpowers](https://github.com/obra/superpowers) that (1) is Jujutsu-native — skills speak `jj` only, work happens on fresh changes on `trunk()`, change IDs are the unit of record, landing is a bookmark move or `jj git push`; (2) adds a roadmap layer — `docs/sjujperpowers/roadmap.md` with milestones that specs and plans reference (`sjujperpowers:roadmapping`); (3) supports only Claude Code, Oh My Pi, Pi, Codex, and OpenCode; (4) drops the browser-based visual brainstorming companion.

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

sjujperpowers is **not published** to the Codex plugin marketplace, so the `/plugins` search will not find it. Until it is, install the skills directly — Codex discovers skills from `~/.agents/skills/`:

```bash
git clone https://github.com/codyw912/sjujperpowers ~/.agents/sjujperpowers
mkdir -p ~/.agents/skills
for s in ~/.agents/sjujperpowers/skills/*/; do ln -sfn "$s" ~/.agents/skills/"$(basename "$s")"; done
```

Update with `git -C ~/.agents/sjujperpowers pull`. The repo also carries a Codex plugin manifest (`.codex-plugin/plugin.json`) and a local marketplace (`.agents/plugins/marketplace.json`) for when it is published; `scripts/package-codex-plugin.sh` builds the archive.

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

1. **roadmapping** (`sjujperpowers:roadmapping`) — Capture long-term milestones in `docs/sjujperpowers/roadmap.md`. Specs and plans name the milestone they serve.
2. **brainstorming** (`sjujperpowers:brainstorming`) — Refine the idea into a spec.
3. **writing-plans** (`sjujperpowers:writing-plans`) — Break the spec into bite-sized tasks.
4. **starting-a-change** (`sjujperpowers:starting-a-change`) — Isolate work on a fresh change on `trunk()`.
5. **executing-plans** (`sjujperpowers:executing-plans`) or **subagent-driven-development** (`sjujperpowers:subagent-driven-development`) — Execute inline in batches, or dispatch a fresh subagent per task with two-stage review.
6. **finishing-a-change-stack** (`sjujperpowers:finishing-a-change-stack`) — Land the stack.

Always-on: **test-driven-development**, **systematic-debugging**, **verification-before-completion**, **requesting-code-review**, **receiving-code-review**.

The agent checks for relevant skills before any task.

## What's inside

- **using-sjujperpowers** — Bootstrap that makes the other skills fire
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
