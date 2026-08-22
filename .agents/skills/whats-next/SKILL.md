---
name: whats-next
description: "Surface the next actionable steps across every active tracked plan (persisted plan, nested plan) so work can resume without ambiguity. This is an infra skill that reads file-based tracked plans under .agents/local/plans/ — not the agent's built-in planning. Use when resuming work, starting a new session, or when unsure what to work on next. Triggers on: 'what's next', 'whats next', 'what should I do', 'resume work', 'show active plans', 'show tracked plans', or at the start of any work session to orient."
---

Surface the next actionable steps across every active plan so work can resume without ambiguity.

## Resolve the plan root

Run the `setup-agentic-scope` resolver from the active working path before enumeration. Scan only `selected_local.plans_path`. When the active scope has no local directory and several ancestors do, report the ambiguity and ask which scope's plans to resume; do not combine plan inventories across local repositories. A user may explicitly request several resolved plan roots, in which case report each root separately.

## Behavior

1. Enumerate plan directories by direct filesystem listing of `{SELECTED_PLANS_ROOT}` (not ignore-aware search), then inspect each `{PLAN_NAME}/plan.md`.
   - Exclude non-plan entries such as `_learnings`, `.gitkeep`, and hidden/system files.
   - Skip plans marked `completed`.
   - Be wise: you do not need to read all content in each `plan.md` if you only need the status line at first.
2. For each active plan:
   - Parse the "Tasks" list and open each referenced task file.
   - Identify tasks with `status` `active`, `paused`, or `pending`; if none exist, flag that new tasks are required.
   - Determine the highest-priority actionable step (e.g., first `active` task with incomplete steps; otherwise the first `pending` task).
3. Produce a summary report:
   - Plan name, priority, and status.
   - Next task name with a short derived hint (e.g., first bullet from "Steps to Complete").
   - Highlight blockers, dependencies, or missing metadata.
4. If no plans are active, explicitly recommend running `create-plan`.

## Output format

```
Plan: {PLAN_NAME} (priority {priority})
- Next task: {TASK_NAME} — {status}
- Suggested action: {short step or reminder}
```

## Notes

- Ensure reverse-chronological progress notes remain untouched; this skill is read-only.
- The summary should be concise to fit a terminal view.
- Plan discovery must be resilient to outer-repository `.gitignore` rules (plan folders may be intentionally ignored).
