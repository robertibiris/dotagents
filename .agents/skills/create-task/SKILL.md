---
name: create-task
description: "Add a task file under an existing tracked plan (persisted plan, nested plan), populate it from the Task File Template, and insert a reference in the parent plan's Tasks list. This is an infra skill — it does NOT use the agent's built-in planning; it creates files under .agents/local/plans/. Use when adding a standalone task to an existing tracked plan mid-work. Triggers on: 'create task', 'add task', 'new task for plan', 'add task to tracked plan', or when decomposing a tracked plan into smaller units of work."
---

Add a task file under an existing tracked plan and insert a reference in the parent plan's Tasks list.

## Resolve the plan root

Before reading or writing tasks, use the `setup-agentic-scope` resolver from the operation's working path and declare `--entry` when the session intentionally began at a broader scope. Use `selected_local.plans_path`; do not assume the repository root or broader entry owns the plan. If the active scope has no local directory, require an explicit `--local` owner on the composed route rather than falling back. Preserve `.agents/local/plans/` for a standalone flat scope.

## Inputs

- `plan_name` (required) — target plan directory under `.agents/local/plans/`.
- `task_name` (required) — descriptive slug for the task (without numeric prefix or extension).
- `purpose` (required) — short description inserted into the "Purpose" section of the task file.
- `position` (optional) — where this task falls in the sequence. If not provided, append after the last existing task.

## Task file naming convention

Task files use a **zero-padded numeric prefix** followed by a descriptive slug:

```
{NN}-{task-name}.md
```

### Initial task creation

When creating tasks as part of a new plan, use sequential two-digit prefixes:

```
01-define-requirements.md
02-design-architecture.md
03-implement-core-logic.md
04-write-tests.md
```

### Inserting tasks between existing ones

When a new task needs to go between existing tasks, use a **dot notation** to insert without renumbering:

```
01-define-requirements.md
02-design-architecture.md
02.1-review-security-constraints.md    ← inserted between 02 and 03
03-implement-core-logic.md
03.1-handle-edge-cases.md              ← inserted between 03 and 04
03.2-add-error-handling.md             ← second insertion between 03 and 04
04-write-tests.md
```

Deeper nesting is allowed for subsequent insertions within insertions:

```
02.1-review-security-constraints.md
02.1.1-audit-auth-flow.md             ← inserted between 02.1 and 02.2
02.2-update-threat-model.md
```

### Rules

- **Two-digit zero-padded** for the primary prefix (`01`, `02`, ... `99`).
- **Dot notation** for insertions — never renumber existing tasks.
- **Filesystem sort order** is the execution order — filenames sort correctly by default.
- **Slug** should be descriptive, ASCII, using dashes for readability.
- The numeric prefix conveys order; the Tasks section in `plan.md` is the authoritative list.

## Behavior

1. Validate that `{SELECTED_PLANS_ROOT}/{PLAN_NAME}` exists and that the target filename does not already exist; abort if either check fails.
2. Determine the numeric prefix:
   - If this is the first task: use `01`.
   - If appending after existing tasks: use the next sequential number.
   - If inserting between existing tasks: use dot notation based on the surrounding task numbers.
3. Generate the task file using `templates/task.md` bundled with this skill. Resolve it from this skill's discovered location rather than the process working directory:
   - Set `belongs_to_plan` to the parent plan name.
   - Initialize `status: active` (or `pending` if it depends on earlier tasks).
   - Populate `created` and `updated` using the canonical timestamp format: `YYYY-MM-DD HH:MM TZ`.
   - Insert the provided `purpose`.
   - Add the actual information relevant to describe the task, as you see fit, respecting markdown format and the template.
4. Insert an entry in the parent `plan.md` "Tasks" section in the correct position, format: `- {NN}-{task-name}.md — {status summary}`.
5. Update the parent plan's `updated` timestamp and progress notes to reflect the new task.

## Side effects

- Creates a new task file in the plan directory.
- Modifies the parent `plan.md` (Tasks section, timestamps, progress notes).

## Notes

- Task filenames should remain ASCII and use dashes for readability.
- If the plan has no prior tasks, replace the placeholder line with the first real entry.
- When inserting, place the new entry in the correct position in the Tasks list — not just at the end.
