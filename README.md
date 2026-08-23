# Agentic Project Template

**AI coding assistants work best when they understand your project.** But each session often starts from scratch—you repeat context, paste snippets, and hope the agent remembers. This template fixes that.

It gives you a **shared, structured context** that both humans and AI agents read from—so everyone works from the same understanding.

---

## In 30 Seconds

A project template that gives AI coding assistants (and humans) a shared context so they can work effectively without re-explaining the project every time. Use it as a starting point for any new project where you want Cursor, GitHub Copilot, Claude, or similar tools to "get" your structure, conventions, and workflow from day one.

---

## The Idea in Practice

Imagine: You clone a repo. You open Cursor. The AI already knows your folder structure, your conventions, and what you're actively working on. No copy-pasting. No re-explaining. It's like onboarding a new teammate who's already read the docs.

**Without this template:**
- New session → paste context → agent forgets → repeat

**With this template:**
- New session → agent reads `AGENTS.md` and `.agents/` → picks up where you left off

---

## Key Benefits

**One source of truth, many agents.** You might use Cursor today, Claude tomorrow, and Copilot in another project. Instead of maintaining separate instructions for each, you keep a single context—`AGENTS.md` and `.agents/`—that every tool reads from. Same structure, same conventions, no drift.

**Collaboration without chaos.** Shared context means everyone on the project—humans and AI—works from the same understanding. At the same time, each person gets a private `.agents/local/` space for plans, personal context, experimental skills, and workflow state. Its optional nested repository keeps local history without cluttering the main project or stepping on teammates' work.

**Complex work across many sessions.** Some initiatives take days or weeks and span dozens of agent sessions. Agents forget between sessions; plans and progress notes don't. You document what you're doing, where you left off, and what's next. When you resume, you (or any agent) run `whats-next` and pick up exactly where you were.

---

## What You Get

- **Shared context** — `AGENTS.md` as the single source of truth; `.agents/` for modular, detailed guidance
- **Plans & tasks** — Structured way to track initiatives and executable units with status and progress notes
- **Platform support** — Works with Codex, Claude Code, Cursor, and GitHub Copilot; each platform uses the same canonical context
- **Local developer space** — Keep plans, personal context, experimental skills, and workflow state outside the main project history
- **Optional nested repo** — Version-control the entire local developer space independently

---

## Project Structure

```
project-root/
├── AGENTS.md                    # Single source of truth (customize for your project)
├── CLAUDE.md                    # Claude integration (references AGENTS.md)
├── .agents/
│   ├── context/                 # Setup and reference docs
│   │   ├── agentic-infrastructure.md      # Normative scope composition
│   │   ├── progressive-disclosure.md      # Metadata-first discovery
│   │   ├── setup-agentic-infrastructure.md # Operational setup guide
│   │   └── platform-adapters.md            # Platform mappings
│   ├── skills/                  # Skill definitions and skill-owned templates
│   │   ├── create-plan/
│   │   │   ├── SKILL.md
│   │   │   └── templates/plan.md
│   │   ├── create-task/
│   │   │   ├── SKILL.md
│   │   │   └── templates/task.md
│   │   ├── update-plan/SKILL.md
│   │   ├── whats-next/SKILL.md
│   │   ├── create-learning/SKILL.md
│   │   ├── setup-local-repo/SKILL.md
│   │   └── ...                  # Additional infra skills
│   └── local/                   # Developer-owned, ignored by the main repo
│       ├── README.md            # Purpose, privacy, and ownership guidance
│       ├── context/             # Personal or machine-specific context
│       ├── skills/              # Personal or experimental skills
│       └── plans/               # Tracked plans, tasks, and learnings
├── .claude/
│   └── skills/                  # Symlink → ../.agents/skills
├── .cursor/
│   └── rules/agentic-scope.mdc # Generated pointer to AGENTS.md
└── .github/
    └── copilot-instructions.md # Generated pointer to AGENTS.md
```

---

## Quick Start

### 1. Use This Template

Clone or use this repo as a template for your new project:

```bash
git clone <this-repo-url> my-project
cd my-project
```

### 2. Customize

- **Edit `AGENTS.md`** — Replace the stub content with your project's overview, structure, conventions, and workflow. This is the main file agents read.
- **Generate platform adapters** — Run the `setup-agentic-scope` adapter command. It creates only the thin files each selected platform needs while leaving canonical knowledge in `AGENTS.md` and `.agents/`.

```bash
ruby .agents/skills/setup-agentic-scope/scripts/scope_tool.rb adapters \
  --scope AGENTS.md
```

### 3. Optional: Set Up Local Version Control

If you want to track your local plans, context, experimental skills, and workflow state with Git without committing them to the main repository, run:

```bash
bash .agents/skills/setup-local-repo/scripts/setup_local_repo.sh \
  --scope-dir .
```

This creates a nested Git repository in `.agents/local/`. The directory also works without nested version control.

### 4. Full Setup Guide

For detailed setup, platform-specific options, and best practices, see [`.agents/context/setup-agentic-infrastructure.md`](.agents/context/setup-agentic-infrastructure.md).

---

## How to Use It

### Resuming Work

Run the `whats-next` skill to see the next actionable steps in the active scope's local directory. The active scope is the only implicit owner; choose another owner explicitly when the session was intentionally composed from a broader entry.

### Creating Work

- **Create a plan** — Use the `create-plan` skill to scaffold a new plan directory and `plan.md` with objectives, requirements, and initial tasks.
- **Create tasks** — Use the `create-task` skill to add executable units under a plan (with numeric prefix naming for execution order).

### Tracking Progress

- **Update plans** — Use the `update-plan` skill to change statuses, create new tasks, revise existing tasks, or complete plans.
- **Capture learnings** — Use the `create-learning` skill to record non-obvious insights during or after plan execution.
- **Progress notes** — Keep them reverse-chronological so the latest updates appear first.

### Skills Reference

| Skill | Purpose |
|-------|---------|
| `whats-next` | Find next actionable steps across active tracked plans |
| `create-plan` | Scaffold a new plan directory with initial tasks |
| `create-task` | Add a task file under an existing plan |
| `update-plan` | Change statuses, add tasks, revise tasks, or complete plans |
| `create-learning` | Capture non-obvious insights as structured learnings |
| `setup-local-repo` | Initialize or migrate the nested repository for developer-owned local content |
| `setup-agentic-context` | Bootstrap agentic infrastructure in a new repo |
| `setup-agentic-scope` | Create independent scopes and compose, inspect, resolve, validate, and adapt direct-child routes |
| `review-agentic-infra` | Audit agent infrastructure |

Skill definitions live in [`.agents/skills/`](.agents/skills/) as the single source of truth. Codex, Cursor, and supported GitHub Copilot surfaces read that directory natively. Claude uses a generated scope-local `.claude/skills/` symlink.

---

## Platform Support

| Platform | File(s) | Notes |
|----------|---------|-------|
| **Codex** | `AGENTS.md`, `.agents/skills/` | Uses canonical scope maps and skills directly; explicit child routes define portable composition |
| **Cursor** | `.cursor/rules/agentic-scope.mdc`, `.agents/skills/` | Generated scoped rule points to `AGENTS.md`; nested canonical skills are discovered natively |
| **GitHub Copilot** | `.github/copilot-instructions.md`, `.github/instructions/` | Generated repository or path-specific instructions point to the applicable scope map |
| **Claude** | `CLAUDE.md`, `.claude/skills/` (symlink) | Generated `CLAUDE.md` imports `AGENTS.md`; the symlink exposes canonical skills |

---

## Best Practices

- **Keep `AGENTS.md` concise** — Put detailed information in `.agents/` files.
- **Keep scopes independent** — Children never point to or depend on a broader entry. Parents register direct children with concise `when` hints.
- **Run `whats-next` when resuming work** — It surfaces the next actionable steps so you can pick up where you left off.
- **Use `.agents/local/` for developer-owned content** — Plans, personal context, experimental skills, scratch work, and private workflow state belong here rather than in shared infrastructure.
- **Use the optional local repository** — Run `setup-local-repo` when you want independent history for the entire developer space.
- **Do not treat local as a secrets vault** — Keep credentials and production secrets in an appropriate secret manager.
- **Avoid duplication** — Platform-specific files should reference `AGENTS.md` and `.agents/`, not repeat their content.

---

## Further Reading

- [`.agents/context/setup-agentic-infrastructure.md`](.agents/context/setup-agentic-infrastructure.md) — Operational setup and migration guide
- [`.agents/context/agentic-infrastructure.md`](.agents/context/agentic-infrastructure.md) — Normative independent-scope and one-way composition architecture
- [`.agents/context/platform-adapters.md`](.agents/context/platform-adapters.md) — Platform capability mappings and adapter contract
- [AGENTS.md](AGENTS.md) — Master reference for plans, tasks, skills, and workflow
- [AGENTS.md pattern](https://agents.md/) — Official documentation for the AGENTS.md pattern
- [Cursor Project Rules](https://cursor.com/docs/context/rules) — Cursor project rules documentation
