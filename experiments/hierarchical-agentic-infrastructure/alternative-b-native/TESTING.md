# Alternative B Test Matrix

Open `borealis-group/` as the repository or workspace and start the agent with `clients/cedar-health/projects/pulse-portal/` as its working directory. Also repeat the test by opening the project leaf as the workspace root; record whether ancestor discovery changes.

Ask:

> Using only automatically discovered instructions, context, and skills, report the effective scope chain, every `CONTEXT_MARKER`, and every scope-provided skill name. Report personal, system, or plugin skills separately. Do not recursively search the repository and do not open sibling scopes.

## Expected Result

```text
Scope chain:
1. Borealis Group
2. Cedar Health
3. Pulse Portal

Context markers:
- BOREALIS-COMPANY-CONTEXT
- CEDAR-CLIENT-CONTEXT
- PULSE-PROJECT-CONTEXT

Skills:
- borealis-governance
- cedar-compliance-review
- pulse-release-check
```

The result must not contain:

- `HARBOR-CLIENT-CONTEXT`
- `harbor-campaign-review`

## Access-Boundary Test

Repeat with an environment whose filesystem access includes only the project leaf and its immediate client. The expected chain is Pulse Portal and Cedar Health. A platform fails this test if it invents Borealis context or silently reads outside the declared boundary.

## Results

| Platform and surface | Company workspace + leaf CWD | Leaf workspace | Access boundary | Notes |
| --- | --- | --- | --- | --- |
| Codex 0.148.0-alpha.9 | Pass | Not run | Partial | Full chain passed without sibling leakage. At the boundary, client/project scopes and both skills were found, but the client context marker was missed because its relative link was resolved from the project working directory. |
| Claude Code | Blocked | Blocked | Blocked | CLI is installed but not authenticated on the test machine. |
| Cursor | Blocked | Blocked | Blocked | Editor is installed, but its agent CLI is not installed; GUI test not run. |
| Copilot CLI | Blocked | Blocked | Blocked | CLI is not installed. |
| Copilot IDE/cloud agent | Not run | Not run | Not run | Record the exact surface and settings. |

## Native Context-Path Question

The initial Codex boundary run shows that native discovery of an ancestor `AGENTS.md` or skill does not necessarily make separately linked context files self-locating. Follow-up variants should compare:

1. Scope-local relative links plus an instruction to resolve them relative to the declaring `AGENTS.md`.
2. Repository-root-qualified context paths.
3. A tiny scope manifest carrying the scope root and context index.

The first variant preserves relocatability and is the best next candidate.
