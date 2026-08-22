---
name: create-plan
description: "Create a new tracked plan (persisted plan, nested plan) with its initial tasks under .agents/local/plans/. This is NOT the agent's built-in planning feature — it creates file-based tracked plans that persist across sessions. Use when starting a new initiative, project, or bounded piece of work. After creating the plan, always identify and create the initial tasks needed to achieve the objective. A plan without tasks is incomplete. Triggers on: 'create plan', 'new plan', 'start a plan for', 'create tracked plan', 'new tracked plan', 'new initiative', or when the user describes work that should be tracked as a persisted plan."
---

Create a new tracked plan directory and initialize `plan.md` with its initial tasks.

**Important**: This skill creates file-based tracked plans under `.agents/local/plans/` — not the agent's built-in planning feature.

## Resolve the plan root

Before reading or writing plans, run the `resolve` command bundled with `setup-agentic-scope`, using the operation's working path as `--start`. Use `selected_local.plans_path` as the plan root. If resolution reports multiple applicable ancestor locals, stop and identify the intended scope with the user, then rerun with `--local`; never choose by Git root or proximity alone. If no local directory exists, create one only when the user wants tracked local state.

## Inputs

- `plan_name` (required) — slug/cased name that becomes the folder under `.agents/local/plans/`.
- `objective` (required) — short description of the plan's intent; inserted into the template's Objective section.
- `priority` (optional, default `medium`) — stored in the plan metadata.
- `tasks` (inferred) — the initial tasks needed to achieve the objective. If the user doesn't list them explicitly, derive them from the objective and discuss with the user before creating.

## Behavior

### Phase 1: Create the plan

1. Confirm the target directory `{SELECTED_PLANS_ROOT}/{PLAN_NAME}` does not already exist; abort with guidance if it does.
2. Create the directory and write `plan.md` using `templates/plan.md` bundled with this skill. Resolve the template from this skill's discovered location, not from the process working directory:
   - Set `status: active`.
   - Populate `priority`, `created`, and `updated` using the canonical timestamp format: `YYYY-MM-DD HH:MM TZ`.
   - Insert the provided `objective` text.
   - Add the actual information relevant to describe the plan, as you see fit, respecting markdown format and the template.
3. Add an initial progress note documenting that the plan was created.

### Phase 2: Create initial tasks

4. Identify the tasks needed to achieve the objective. If the user provided them, use those. If not, propose a task breakdown and confirm with the user before proceeding.
5. For each task, **follow the discovered `create-task` skill** to create the task file. This ensures consistent naming (numeric prefixes), template usage, and parent plan updates without assuming that skill lives at the active scope.
6. Update the plan's progress notes to reflect task creation.

**A plan without tasks is incomplete.** Always ensure at least one task is created before finishing.

## Side effects

- Creates directories/files under `{SELECTED_PLANS_ROOT}/{PLAN_NAME}/`.
- Creates one or more task files within the plan directory.
- Emits guidance about next steps (e.g., "Run `whats-next` to see actionable items").

## Notes

- Always use reverse-chronological ordering when writing progress entries.
- If priority is omitted, default to `medium` to keep metadata consistent.
- Task filenames should remain ASCII and use dashes or underscores for readability.
