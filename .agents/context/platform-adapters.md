---
name: agentic-platform-adapters
description: Canonical mappings and constraints for exposing independent and composed agentic scopes to Codex, Claude Code, Cursor, and GitHub Copilot.
---

# Platform Adapters

Adapters expose canonical maps, context, and skills defined in `AGENTS.md` and `.agents/`. They must not become independent sources of organizational, product, or workflow knowledge.

## Principles

- Canonical behavior comes from `agentic-infrastructure.md` and `progressive-disclosure.md`.
- Each scope must work when opened independently.
- Broader composition is explicit parent-to-child routing; platform inheritance is an optimization, not the contract.
- Platform files contain references and mechanics only.
- Generation and repair are idempotent.
- Equivalent behavior is required; identical platform configuration is not.
- Validation records the product surface and version.

## Capability Mapping

| Platform | Instructions | Skills | Adapter strategy |
| --- | --- | --- | --- |
| Codex | Native `AGENTS.md` | Native `.agents/skills/` | Use canonical files directly; explicit child maps provide portable composition. |
| Claude Code | `CLAUDE.md` imports `AGENTS.md` | Scope-local `.claude/skills` | Generate one thin import and local canonical skill link per participating scope. |
| Cursor | `AGENTS.md` plus scoped rules | Native scope-local skills where supported | Generate a nested rule pointing to the canonical map. |
| GitHub Copilot | Repository and path-specific instructions; `AGENTS.md` support varies by surface | `.agents/skills/` support varies by surface | Generate repository or path-specific pointers and validate the selected surface. |

## Codex

Codex can consume canonical `AGENTS.md` and `.agents/skills/` files directly. No duplicated adapter content is required.

Native filesystem discovery does not define composition. When a session begins at a broader entry, route only through that entry's explicit child registrations and their hints. When a child is opened by itself, do not reconstruct broader context from filesystem location.

## Claude Code

At each participating scope, generate:

```markdown
@AGENTS.md
```

When the scope owns shared skills, expose only its local canonical directory:

```text
.claude/skills -> ../.agents/skills
```

Do not link a child to a flattened or broader skill directory. A child adapter must remain valid when the child is distributed alone.

## Cursor

Use a nested `.cursor/rules/` file as the portable pointer:

```markdown
---
description: Load the canonical agentic scope map for this directory tree
alwaysApply: true
---

Use `AGENTS.md` in this directory as the canonical scope map. Resolve registered paths from that file and follow its progressive-disclosure rules.
```

Do not copy context bodies or complete skills into Cursor rules. Native nested discovery may accelerate local lookup, but explicit child registration still determines broader composition.

## GitHub Copilot

Copilot behavior varies across CLI, IDE, cloud-agent, and review surfaces. At a repository root, `.github/copilot-instructions.md` points to the root scope map. For nested scopes, generate `.github/instructions/{scope-path}.instructions.md` with an `applyTo` glob and canonical map reference.

Generated files contain routing mechanics only. Validate the actual surface because support for `AGENTS.md`, path instructions, and skills is not uniform.

## Generation Boundary

Adapters are generated relative to the participating platform workspace or containing repository, not one-for-one with conceptual scope composition. Several scopes in one repository may require local Claude and Cursor adapters plus repository-root Copilot path instructions.

A nested scope that is also distributed as a standalone repository must have valid adapters at its own root without assuming any broader entry exists.

## Generate, Repair, or Check

Set `SETUP_AGENTIC_SCOPE_SKILL_DIR` to the discovered skill directory, then run:

```bash
ruby "${SETUP_AGENTIC_SCOPE_SKILL_DIR}/scripts/scope_tool.rb" adapters \
  --scope path/to/AGENTS.md
```

The command reports native Codex behavior, writes only marked generated files, repairs stale managed files and Claude symlinks, and refuses to overwrite unmanaged files. Use `--dry-run`, `--check`, or `--platforms codex,claude,cursor,copilot` as needed.

## Validation

For every supported surface, verify:

- Each scope works when opened independently.
- A broader entry can route to a requested descendant through explicit hints.
- The chosen child's authoritative header is verified before its body or resources are loaded.
- Registered scope skills are reachable without flattening unrelated scopes.
- Context metadata is discoverable without eager body loading.
- Registered paths resolve from their declaring scope.
- Siblings remain undisclosed unless explicitly targeted.
- Adapter files contain no duplicated canonical knowledge.
- Broken symlinks and stale path-specific rules are reported.

## References

Platform discovery claims in this guide were rechecked against the official documentation below on 2026-08-24. Runtime validation should still record the exact product version and surface.

- [Codex skills](https://developers.openai.com/codex/skills)
- [Codex `AGENTS.md`](https://learn.chatgpt.com/docs/agent-configuration/agents-md)
- [Claude Code skills](https://code.claude.com/docs/en/slash-commands)
- [Claude Code memory](https://code.claude.com/docs/en/memory)
- [Cursor rules](https://docs.cursor.com/context/rules-for-ai)
- [Cursor agent skills](https://cursor.com/docs/skills)
- [GitHub Copilot CLI custom instructions](https://docs.github.com/en/copilot/how-tos/copilot-cli/customize-copilot/add-custom-instructions)
- [GitHub Copilot CLI skill locations](https://docs.github.com/en/copilot/reference/copilot-cli-reference/cli-command-reference#skill-locations)
- [GitHub Copilot instruction support](https://docs.github.com/en/copilot/reference/custom-instructions-support)
