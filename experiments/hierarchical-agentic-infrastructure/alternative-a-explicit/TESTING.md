# Alternative A Test Matrix

Start each platform with `atlas-collective/clients/aster-labs/projects/orbit-console/` as its working folder. If the platform requires a repository workspace, open `atlas-collective/` and set the task's working directory to that leaf.

Ask:

> Read the local `AGENTS.md` and follow its hierarchy protocol. Report the effective scope chain, every `CONTEXT_MARKER`, and every scope-provided skill name. Do not inspect children or siblings.

## Expected Result

```text
Scope chain:
1. Atlas Collective
2. Aster Labs
3. Orbit Console

Context markers:
- ATLAS-COMPANY-CONTEXT
- ASTER-CLIENT-CONTEXT
- ORBIT-PROJECT-CONTEXT

Skills:
- atlas-governance
- aster-engagement-review
- orbit-release-check
```

The result must not contain:

- `EMBER-CLIENT-CONTEXT`
- `ember-portfolio-review`

## Boundary Test

Copy only `clients/aster-labs/projects/orbit-console/` and `clients/aster-labs/` to a temporary workspace, preserving their relative relationship but omitting the company root. The expected chain is Orbit Console and Aster Labs only. The agent must report that the next parent is inaccessible and must not reconstruct Atlas context from names or assumptions.

## Results

| Platform | Full-chain result | Boundary result | Notes |
| --- | --- | --- | --- |
| Codex 0.148.0-alpha.9 | Pass | Pass | Passed after skills moved to the deliberately non-native `.agents/catalog/skills/` path. No sibling marker or skill appeared. |
| Claude Code | Blocked | Blocked | CLI is installed but not authenticated on the test machine. |
| Cursor | Blocked | Blocked | Editor is installed, but its agent CLI is not installed; GUI test not run. |
| GitHub Copilot | Blocked | Blocked | CLI is not installed. Record the tested surface when this is run manually. |
