# Platform Validation Evidence

Validated on 2026-08-22 CEST against a disposable copy of Alternative C. The structural validator is the platform-independent correctness baseline; live sessions test product discovery behavior without becoming another source of truth.

## Compatibility Matrix

| Platform surface | Version / configuration | Full chain | Partial access | Native instructions | Native skills | Status |
| --- | --- | --- | --- | --- | --- | --- |
| Codex CLI | `codex-cli 0.148.0-alpha.9`; `gpt-5.6-sol`; read-only sandbox; ephemeral sessions | Northstar → Aurora → Lumen; all three registered context markers and skill names; no Solstice body or skill | Aurora → Lumen; stopped at missing `/partial/AGENTS.md`; no company inference | Supplied all three `AGENTS.md` scopes at session start in root-to-leaf order | Supplied `northstar-governance`, `aurora-review`, and `lumen-release` at session start | Passed |
| Claude Code CLI | `2.1.177`; Read tool only; project settings; no session persistence | Not run | Not run | Not verified live | Not verified live | Blocked: configured OAuth token was revoked (`401`) |
| Cursor | Executable not present in the validation environment | Not run | Not run | Not verified live | Not verified live | Blocked: surface unavailable |
| GitHub Copilot CLI | Executable not present in the validation environment | Not run | Not run | Not verified live | Not verified live | Blocked: surface unavailable |

Official product documentation was refreshed before implementation. Documentation-backed mappings remain recorded in `platform-adapters.md`, but the three blocked surfaces above are not claimed as live-validated.

## Consistent Behavioral Prompt

Run from the Lumen project leaf with a read-only tool policy:

```text
Read-only hierarchy validation. Do not modify files. Do not recursively search,
enumerate directories, use find or globbing, or inspect siblings. Starting at the
current leaf, follow only declared scope.parent pointers in AGENTS.md. For each
readable scope in that chain, resolve registered resource paths relative to the
AGENTS.md that declares them. Read each registered context body and only the
frontmatter of each registered SKILL.md. Report the scope chain root to leaf,
exact context BODY-SENTINEL markers, registered skill names, whether any Solstice
sibling name, marker, or skill appeared, and exact source paths used.
```

For partial access, use the copied Aurora subtree and add: `Stop at the first unreadable parent and do not infer unavailable company content.`

## Codex Evidence

The full-chain run reported:

- Scope chain: `northstar-holdings → aurora-analytics → lumen-migration`.
- Context: `NORTHSTAR-COMPANY-BODY-SENTINEL`, `AURORA-CLIENT-BODY-SENTINEL`, and `LUMEN-PROJECT-BODY-SENTINEL`.
- Skills: `northstar-governance`, `aurora-review`, and `lumen-release`.
- Solstice: its direct-child route was visible in the Northstar map, as required for parent routing, but no Solstice context marker or skill was read.
- Every reported resource path resolved from its declaring scope.

The reduced-access run reported only Aurora and Lumen resources, identified the missing parent path, and explicitly declined to infer company content.

Two no-tool startup checks separately confirmed that Codex supplied:

1. The three scope instructions in root-to-leaf order.
2. The three scope-local project skills from the working directory through the repository root.

Non-blocking environment warnings concerned inaccessible personal skill directories and did not affect the isolated repository skills.

## Reproduction Setup

1. Copy `alternative-c-hybrid/northstar-holdings` to a temporary directory.
2. Initialize Git at the copied company root.
3. Run `scope_tool.rb adapters` at the company, both clients, and the Lumen project.
4. Launch the platform from the Lumen directory with read-only permissions and the consistent prompt.
5. For partial access, copy only `clients/aurora-analytics`, initialize that client as the visible repository root, regenerate its adapters, and rerun from Lumen.
6. Record the exact product version, model, permission mode, settings sources, output, and blockers.

Do not convert a platform failure into copied context inside an adapter. Feed it back into the canonical resolver, platform mapping, or an explicitly documented unsupported-surface result.
