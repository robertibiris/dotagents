---
name: update-plan
description: "Update a tracked plan (persisted plan, nested plan) — change task statuses, create new tasks discovered mid-work, revise existing task steps or requirements, or wrap up a completed plan. This is NOT the agent's built-in planning feature — it updates file-based tracked plans under .agents/local/plans/. Use when: work was completed and statuses need updating, new work was discovered that needs a new task, an existing task's approach changed and needs revision, or the entire plan is done and should be closed out. Triggers on: 'update plan', 'update status', 'mark task done', 'complete plan', 'add a task', 'revise the plan', 'I finished X', 'wrap up the plan', 'the plan needs changes', or any request to mutate tracked plan state."
---

Update a tracked plan — statuses, new tasks, task revisions, or plan completion.

**Important**: This skill updates file-based tracked plans under `.agents/local/plans/` — not the agent's built-in planning feature.

## Resolve the plan root

Before resolving `target`, run the `setup-agentic-scope` resolver from the operation's working path. Use `selected_local.plans_path` as the only implicit plan root. If multiple ancestor locals remain applicable, infer an explicit scope only from clear session context; otherwise stop and ask. Never choose a plan merely because another repository or local directory has a matching name.

## Inputs

- `target` (required) — path or identifier of the plan (`plan`) or task (`plan/task`). **ALWAYS try to infer it first** from the current session context. If truly unclear, ask the user.
- `changes` (inferred) — what needs updating. Infer from the user's message. May include any combination of the mutation types below.

**IMPORTANT**: If the user does not provide inputs explicitly, ALWAYS try to infer them from the context of your interaction with the user in the current session. If truly unclear, ask.

## Mutation types

This skill handles four types of plan mutations — any combination may apply in a single invocation:

### 1. Status changes

Update the `status` field of a task or plan (`pending`, `active`, `paused`, `completed`) and the `updated` timestamp. Append a progress note documenting the change.

### 2. New tasks

Create new task files for work discovered mid-plan. Use `templates/task.md` bundled with the discovered `create-task` skill, without resolving it from the process working directory. Follow that skill's numeric prefix naming convention — use dot notation (e.g., `02.1-`) to insert between existing tasks without renumbering. Update the parent plan's "Tasks" section and progress notes.

### 3. Task revisions

Modify existing task files — update steps, change approach, add/remove requirements, adjust scope. Append a progress note explaining what changed and why.

### 4. Plan completion

When all tasks are done, verify all tasks show `completed` status. If any don't, warn the user. Set the plan status to `completed` and append a final progress note summarizing what was accomplished.

## Behavior

1. **Assess what changed.** Parse the user's message to determine which mutation types apply.
2. **Resolve target files:**
   - Plans: `{SELECTED_PLANS_ROOT}/{PLAN_NAME}/plan.md`
   - Tasks: `{SELECTED_PLANS_ROOT}/{PLAN_NAME}/{TASK_NAME}.md`
3. **Apply mutations:**
   - For status changes: update `status` and `updated` timestamp.
   - For new tasks: create task files, update parent plan's Tasks section.
   - For task revisions: modify the task file's steps, requirements, or approach.
   - For plan completion: verify all tasks are completed, set plan status.
4. **Append progress notes** to affected files, ensuring newest entries appear first.
5. **Propagate changes** — if task statuses changed, update the parent plan's Tasks section summary. If all tasks are completed, recommend completing the plan.

## Side effects

- Mutates task files and/or the parent plan file.
- May create new task files.
- Produces console output summarizing changes and suggesting next steps.

## Notes

- Never remove historical progress notes; always prepend the newest entry.
- Status transitions should be idempotent — setting the same status twice should simply append a note if provided.
- Use the canonical timestamp format: `YYYY-MM-DD HH:MM TZ`.
