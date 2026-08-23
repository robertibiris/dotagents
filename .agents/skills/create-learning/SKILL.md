---
name: create-learning
description: "Capture non-obvious, hard-won insights as structured learnings — either within a specific tracked plan (persisted plan, nested plan) or as cross-cutting reference docs. This infra skill writes to .agents/local/plans/{PLAN}/learnings.md or .agents/local/plans/_learnings/. Use when insights, patterns, or gotchas emerge during work that future contributors should know. Triggers on: 'create learning', 'capture learnings', 'what did we learn', 'record insights', 'add learnings', 'save learnings', or when non-obvious discoveries surface during plan execution."
---

Interactively create or update learnings documents so non-obvious, hard-won insights are captured in a consistent format.

**Important**: This skill writes to file-based tracked plans under `.agents/local/plans/` — not the agent's built-in planning feature.

## Resolve the plan root

Use the `setup-agentic-scope` resolver before selecting a learning file, declaring the broader `--entry` when composition is intentional, and interpret every path below relative to `selected_local.plans_path`. The active scope is the only implicit owner; use `--local` to deliberately choose another owner on the composed route. Do not write into a broader entry or Git root by proximity.

## Interactive flow

### 1. Determine scope

- **Plan-specific** → write to `.agents/local/plans/{PLAN_NAME}/learnings.md`
- **Cross-cutting** → write to `.agents/local/plans/_learnings/{topic-name}.md`

### 2. Identify target

- For plan-specific learnings, **infer the current plan from session context first**. If unclear, ask the user.
- If no plan exists for plan-specific learnings, offer to create a minimal plan folder before writing.
- For cross-cutting learnings, ask for a short topic slug (e.g., `content-ingestion-patterns`).

### 3. Gather content

- **First**: proactively propose learnings from current session context (discussion, decisions, tool outputs, and fixes).
- **Second**: if current session context is thin, offer to analyze the current branch (commits, diffs, PR notes) and propose learnings.
- **Third**: ask the user to provide learnings directly.
- Present a proposed list for confirmation/refinement before drafting.

### 4. Draft and confirm

- Structure the file using `templates/learnings.md` bundled with this skill, resolved from the discovered skill location rather than the process working directory.
- Show the full drafted content and request explicit confirmation.
- Write files only after explicit confirmation.

## Content quality guidelines

- Focus on surprising, non-obvious insights, not generic best practices.
- Capture what was learned and why it matters, not just what was done.
- Include practical implications that future contributors can apply quickly.
- Ensure each learning includes a clear, actionable `**Takeaway:**` line.

## Existing file behavior

- If `.agents/local/plans/{PLAN_NAME}/learnings.md` exists, append new sections and continue numbering.
- If `.agents/local/plans/_learnings/{topic-name}.md` exists, ask whether to update the existing file or create a new topic file.
- Preserve reverse-chronological progress notes in related plan/task files when they are updated as part of this workflow.

## Output

- New or updated learnings file in the appropriate location.
- Short confirmation message summarizing what was created or updated.
