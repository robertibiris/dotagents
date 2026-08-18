---
name: agentic-platform-adapters
description: Canonical mappings and constraints for exposing hierarchical agentic scopes to Codex, Claude Code, Cursor, and GitHub Copilot.
---

# Platform Adapters

Platform adapters expose the canonical scope maps, context, and skills defined in `AGENTS.md` and `.agents/`. They must not become independent sources of company, client, project, or workflow knowledge.

## Adapter Principles

- Canonical behavior comes from `agentic-infrastructure.md` and `progressive-disclosure.md`.
- Native discovery is an optimization, not the contract.
- Platform files contain references and platform mechanics only.
- Generation and repair must be idempotent.
- Equivalent effective context is required; identical platform configuration is not.
- Product surfaces and versions must be recorded when validating behavior.

## Capability Mapping

| Platform | Instructions | Skills | Scoped adapter strategy |
| --- | --- | --- | --- |
| Codex | Native hierarchical `AGENTS.md` | Native `.agents/skills/` from the working directory through repository root | Use canonical files directly; explicit scope maps cover inaccessible or non-native paths. |
| Claude Code | Hierarchical `CLAUDE.md` and imported `AGENTS.md` | Scope-local `.claude/skills` discovery | Generate a thin `CLAUDE.md` reference and a local skill-directory link at participating scopes. |
| Cursor | Nested `.cursor/rules/` | Do not assume portable nested skill discovery | Generate scoped rules that point to the local `AGENTS.md` and canonical registries. |
| GitHub Copilot | `AGENTS.md`, repository instructions, and path-specific instructions depending on surface | `.agents/skills/` on supported surfaces | Generate repository and path adapters from visible scope maps; record the tested Copilot surface. |

## Codex

Codex can consume the canonical `AGENTS.md` and `.agents/skills/` hierarchy directly. No duplicated adapter content is required.

The explicit parent/direct-child protocol remains necessary because:

- A context chain may cross a repository or workspace boundary that native discovery does not traverse.
- Separately linked context must retain declaring-scope path provenance.
- Missing ancestors must produce a defined partial-chain result.

Validation should start Codex from the relevant leaf while preserving the intended accessible filesystem tree.

## Claude Code

At a participating scope, generate a minimal `CLAUDE.md`:

```markdown
@AGENTS.md
```

When scoped skill discovery requires it, create:

```text
.claude/skills -> ../.agents/skills
```

The link belongs to the scope whose skills it exposes. Do not link a client or project adapter to a global flattened skill directory.

Claude testing must verify both instruction inheritance and the availability of skills from every accessible ancestor. If a platform-native chain differs from the canonical scope chain, the canonical traversal rules determine expected behavior.

## Cursor

Use nested `.cursor/rules/` as the portable scoped mechanism. A generated rule should contain only bootstrap guidance, for example:

```markdown
---
description: Load the canonical agentic scope map for this directory tree
alwaysApply: true
---

Use the applicable `AGENTS.md` as the canonical scope map. Resolve its registered paths from the directory containing that file and follow progressive-disclosure rules.
```

Do not copy context bodies or complete skill instructions into Cursor rules. Do not assume `.cursor/skills` behaves consistently across products or versions without current test evidence.

## GitHub Copilot

Copilot capabilities vary by CLI, IDE, cloud agent, and code-review surface.

At a repository root, `.github/copilot-instructions.md` should point to the root scope map. When the surface supports path-specific instructions, generate `.github/instructions/{scope-name}.instructions.md` with an `applyTo` glob and a reference to the applicable scope map.

Generated instructions contain routing mechanics only. They must not duplicate scope context. Validation records the exact Copilot surface and configuration because support for `AGENTS.md`, path instructions, and skills is not uniform.

## Generation Boundary

Adapters are generated relative to the platform workspace or containing repository, not assumed to exist one-for-one with context scopes.

For example, several scopes inside one repository may require:

- Native scope files at each scope for Codex.
- Scope-local Claude files and skill links.
- Nested Cursor rules.
- A repository-root Copilot instructions directory containing several path-specific adapters.

If a nested scope is also distributed as a standalone repository, adapter generation at that repository root must remain valid when ancestors are absent.

## Validation

For every supported platform and surface, verify:

- The active leaf and accessible ancestors are identifiable.
- Registered scope skills are available or reachable.
- Context metadata is discoverable without eager body loading.
- Registered paths resolve from their declaring scope.
- Sibling scope knowledge is absent unless explicitly targeted.
- Missing ancestors stop cleanly.
- Adapter files contain no duplicated business context.
- Broken symlinks and stale path-specific rules are reported.

## References

- [Codex skills](https://developers.openai.com/codex/skills)
- [Codex `AGENTS.md`](https://learn.chatgpt.com/docs/agent-configuration/agents-md)
- [Claude Code skills](https://code.claude.com/docs/en/slash-commands)
- [Claude Code memory](https://code.claude.com/docs/en/memory)
- [Cursor rules](https://docs.cursor.com/context/rules-for-ai)
- [GitHub Copilot CLI custom instructions](https://docs.github.com/en/copilot/how-tos/copilot-cli/customize-copilot/add-custom-instructions)
- [GitHub Copilot instruction support](https://docs.github.com/en/copilot/reference/custom-instructions-support)
