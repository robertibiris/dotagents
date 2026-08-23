---
name: dotagents-template
description: Root scope for the reusable agentic infrastructure template, its canonical architecture, shared skills, and local workflow conventions.
type: template
children: []
resources:
  context:
    - .agents/context/agentic-infrastructure.md
    - .agents/context/progressive-disclosure.md
    - .agents/context/setup-agentic-infrastructure.md
    - .agents/context/platform-adapters.md
  skills:
    - .agents/skills/create-learning/SKILL.md
    - .agents/skills/create-plan/SKILL.md
    - .agents/skills/create-task/SKILL.md
    - .agents/skills/review-agentic-infra/SKILL.md
    - .agents/skills/setup-agentic-context/SKILL.md
    - .agents/skills/setup-agentic-scope/SKILL.md
    - .agents/skills/setup-local-repo/SKILL.md
    - .agents/skills/update-plan/SKILL.md
    - .agents/skills/whats-next/SKILL.md
---

# 🤖 Agentic Context

This is a stub template file used to setup new 
projects with a common agentic infrastructure. When 
setting up the project, fill out any void sections 
with the details of the REAL project.

## Tracked Plans Overview

In this repository a **tracked plan** refers to a file-based plan under `.agents/local/plans/`, not an agent's built-in planning feature.

- **Tracked plan**: A bounded initiative documented in `plan.md` under `.agents/local/plans/{PLAN_NAME}`. Plans contain the intent, requirements, high-level steps, links to their tasks, and a reverse-chronological progress log.
- **Task**: An executable unit inside the same plan folder (`{NN}-{TASK_NAME}.md`). Tasks reference their parent plan, list concrete steps, outputs, dependencies, and track progress notes the same way plans do. Task files use a zero-padded numeric prefix for execution order (see `create-task` skill for naming convention).
- **Learning**: Insights captured during plan execution, stored in `learnings.md` within each plan directory. Cross-cutting reference docs live in `_learnings/`. Use the `create-learning` skill to create interactively.
- **Status**: `pending`, `active`, `paused`, or `completed`. Status is stored in each file's front-matter block and is updated whenever work is waiting to be picked up (`pending`), currently in progress (`active`), temporarily halted (`paused`), or done (`completed`).
- **Progress notes**: Appended in reverse chronological order every time a material update happens (new insight, partial delivery, blockers, etc.).
- **Workflow**: Create or select a plan, decompose into tasks, execute tasks incrementally, append notes, and keep statuses accurate so that automation can determine "what's next."

## Key Terminology

| Canonical term | Aliases | Meaning |
| --- | --- | --- |
| **Tracked plan** | persisted plan, nested plan, custom plan | A file-based plan under `.agents/local/plans/` — NOT the agent's built-in planning |
| **Local directory** | local repo, developer space | Git-ignored developer-owned content under `.agents/local/`, optionally versioned in its own nested repository |
| **Infra skills** | infrastructure skills, agent infra skills | Skills for managing agentic infrastructure |

## Agentic Infrastructure Description

- `AGENTS.md` (this file) is the map for this independent context scope. Its frontmatter may register direct children with routing hints and local agent-addressable resources without eagerly loading their bodies. It never lists active plans.
- `.agents/` stores all structured context:
  - `.agents/context/agentic-infrastructure.md` is the normative architecture for independent scopes, one-way composition, navigation, path semantics, access boundaries, and adapters.
  - `.agents/context/progressive-disclosure.md` defines registered agent-addressable Markdown, metadata-first inspection, and selective body loading.
  - `.agents/context/setup-agentic-infrastructure.md` is the operational installation and migration guide.
  - `.agents/context/platform-adapters.md` documents how each supported platform exposes the canonical infrastructure.
  - `.agents/skills/` holds skill definitions. Each skill is a directory containing a `SKILL.md` with YAML frontmatter (name, description) and instructions. Templates used by one skill live with that skill. Codex, Cursor, and supported GitHub Copilot surfaces consume this canonical directory natively; Claude adapters expose it through a scope-local `.claude/skills` symlink.
  - `.agents/local/` is the developer-owned space for content that is useful locally but should not be committed to the main repository. It starts with `context/`, `skills/`, and `plans/`, may contain other local files, and can optionally be versioned through the `setup-local-repo` skill.
  - `.agents/local/plans/` groups every tracked plan by name. Each plan directory contains:
    - `plan.md` – metadata, objectives, requirements, steps, tasks summary, and progress log.
    - `{NN}-{TASK_NAME}.md` – one file per task with metadata, steps, outputs, dependencies, and progress notes. Files use a numeric prefix for execution order.
    - `learnings.md` (optional) – plan-specific insights discovered during execution.
  - `.agents/local/plans/_learnings/` stores cross-cutting reference documents (topic-named, not tied to any single plan).
- The optional nested repository belongs at `.agents/local/`, not inside `plans/`. This lets one local history cover plans, personal context, experimental skills, scratch work, and other developer-specific state without exposing those files to the outer repository.

## Scope Navigation

- Treat each `AGENTS.md` as a map of its own scope, not as an eager knowledge bundle.
- Inspect registered resource frontmatter before deciding whether to read a complete body.
- Resolve every registered path relative to the `AGENTS.md` that declares it.
- From a broader entry, follow only declared direct-child routes required by the task. A child opened independently has no parent dependency.
- Use each parent-owned `when` hint to narrow routing, then verify the selected child's authoritative header before entering it.
- Do not enumerate or load sibling scopes unless the task explicitly targets them.
- Stop cleanly when a declared scope is outside granted filesystem or workspace access.
- Apply the instructions of each scope on the explicitly composed entry-to-active route; do not infer broader instructions when a child is opened independently.
- Plans and tasks must not be merged together; every concern has its own file. Metadata, timestamps, and note ordering must stay consistent across the hierarchy.

## Skills Index

### Infra skills (tracked plan management)

- **`.agents/skills/create-plan/`** — Scaffold a new tracked plan directory with initial tasks
- **`.agents/skills/create-task/`** — Add a task file under an existing tracked plan (numeric prefix naming convention)
- **`.agents/skills/update-plan/`** — Update a tracked plan: change statuses, create new tasks, revise existing tasks, or complete the plan
- **`.agents/skills/whats-next/`** — Scan all tracked plans, find active items, determine next actionable steps
- **`.agents/skills/create-learning/`** — Capture non-obvious insights as structured learnings (plan-specific or cross-cutting)

### Infra skills (infrastructure setup and maintenance)

- **`.agents/skills/setup-agentic-context/`** — Bootstrap agentic infrastructure in a new repo
- **`.agents/skills/setup-agentic-scope/`** — Create independent scopes and compose, inspect, resolve, and validate one-way child routes
- **`.agents/skills/setup-local-repo/`** — Initialize a nested git repository in `.agents/local/` for developer-owned content
- **`.agents/skills/review-agentic-infra/`** — Review and audit agent infrastructure

## Guidance for Resuming Work

1. Resolve the active scope with `setup-agentic-scope`. Its local directory is the only implicit plan owner; select another scope on an explicit composed route only when deliberately requested.
2. Run the `whats-next` skill to list every active tracked plan in the resolved local directory and its next actionable task.
3. Open the indicated `plan.md` or task file under the resolved `plans/` directory.
4. Review the latest progress notes (remember they are reverse chronological).
5. Continue execution, update steps or requirements if needed, and append a new progress entry with timestamps before pausing or completing the work.

## Assistant Behavior Requirements

- Enforce the directory, file, and naming structure exactly as documented.
- Resolve the active scope and local owner before implicit plan operations; never fall back silently to a broader entry or Git root.
- Keep each plan and task in its own file; never co-mingle scopes or duplicate metadata.
- Whenever interacting with a plan or task, summarize the current state and propose the next logical step before making changes.
- Suggest creating a task whenever a plan's step grows complex or ambiguous.
- Maintain timestamps, status fields, and reverse-chronological progress notes with every update.
- Record all dates/times using the local system timezone as reported by `date`, and include hour/minute stamps (`YYYY-MM-DD HH:MM TZ`) so metadata and progress notes remain consistent without manual adjustments.
- Surface any missing metadata or structural inconsistencies and fix them before proceeding.
- After completing or pausing work, always recommend running the `whats-next` skill so future sessions can resume seamlessly.

### Markdown hygiene

- Use **`path`** (bold wrapping code), not `` `**path**` `` (code span swallowing emphasis).
- Do not wrap markdown links in backticks: use `[text](url)`, not `` `[text](url)` ``.
- In this file, use **`.agents/skills/...`** style for the skills index; the "Where to look" tables in other docs use real links.
