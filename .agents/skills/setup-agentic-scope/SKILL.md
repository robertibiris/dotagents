---
name: setup-agentic-scope
description: "Create, register, inspect, resolve, and validate independently usable agentic context scopes. Use when adding any scoped AGENTS.md, composing a parent entry from direct children with routing hints, registering local context or skills, inspecting metadata without bodies, finding child candidates in an explicit container, or creating optional scope-local .agents/local/ state."
---

# Setup Agentic Scope

Use the bundled tool to keep scope composition deterministic. Each scope stands alone. A broader entry scope may register it as a direct child, but the child never records or depends on that parent.

Set `SETUP_AGENTIC_SCOPE_SKILL_DIR` to the absolute directory containing this discovered `SKILL.md`, then resolve `scripts/scope_tool.rb` beneath it. Never assume the process working directory contains the skill.

## Create or repair an independent scope

```bash
ruby "${SETUP_AGENTIC_SCOPE_SKILL_DIR}/scripts/scope_tool.rb" setup \
  --scope-dir initiatives/atlas \
  --name atlas-initiative \
  --description "Independent scope for Atlas delivery and its services." \
  --type initiative
```

Only `name` and `description` are required. `type`, `children`, and `resources` are optional and omitted when unused. Add `--with-local` only when this scope owns developer-local state, `--confidential` for co-location audit warnings, and `--dry-run` to preview writes.

Register existing local resources with repeatable options:

```bash
ruby "${SETUP_AGENTIC_SCOPE_SKILL_DIR}/scripts/scope_tool.rb" setup \
  --scope-dir initiatives/atlas \
  --context .agents/context/architecture.md \
  --skill .agents/skills/release-check/SKILL.md
```

The operation validates registered headers before mutation, preserves the existing `AGENTS.md` body, and writes through a rollback-capable transaction.

## Register a direct child on its parent

```bash
ruby "${SETUP_AGENTIC_SCOPE_SKILL_DIR}/scripts/scope_tool.rb" register-child \
  --scope AGENTS.md \
  --child initiatives/atlas/AGENTS.md \
  --when "Use for Atlas delivery work or any of its services."
```

`--when` is a concise, parent-owned routing hint. It tells an agent when to inspect that child without copying the child's authoritative identity or instructions. Registration changes only the parent map. Repeating the command updates the hint without duplicating the route. The same child may be registered by several independent parents.

## Inspect progressive metadata

```bash
ruby "${SETUP_AGENTIC_SCOPE_SKILL_DIR}/scripts/scope_tool.rb" inspect \
  --scope AGENTS.md \
  --include map,resources,children \
  --format json
```

Inspection reads frontmatter only and returns path provenance with `body_loaded: false`. Child records contain the parent-owned `routing_hint` and the child's authoritative `name` and `description`. Use hints to narrow candidates, then verify the selected child's header before entering it. Read a full resource body only when its description is relevant.

## Resolve standalone or composed work

Opening a scope independently resolves only that scope:

```bash
ruby "${SETUP_AGENTIC_SCOPE_SKILL_DIR}/scripts/scope_tool.rb" resolve \
  --start initiatives/atlas \
  --format json
```

When the session intentionally began at a broader entry, declare it explicitly:

```bash
ruby "${SETUP_AGENTIC_SCOPE_SKILL_DIR}/scripts/scope_tool.rb" resolve \
  --entry AGENTS.md \
  --start initiatives/atlas/services/orbit \
  --format json
```

The resolver follows only registered downward routes. It never searches for a parent. The active scope's `.agents/local/` is the only implicit local owner. If the active scope has no local directory, `selected_local` remains empty; pass `--local path/to/.agents/local` to deliberately select another owner already on the composed route.

## Find candidate direct children

```bash
ruby "${SETUP_AGENTIC_SCOPE_SKILL_DIR}/scripts/scope_tool.rb" candidates \
  --scope AGENTS.md \
  --under initiatives
```

Candidate discovery scans only immediate subdirectories of explicitly selected containers. It reports candidates without modifying them. Review the output and register only intended children with `register-child`.

## Validate a scope

```bash
ruby "${SETUP_AGENTIC_SCOPE_SKILL_DIR}/scripts/scope_tool.rb" validate \
  --scope AGENTS.md \
  --descendants \
  --format text
```

Single-scope validation checks the lean schema, mandatory child hints, identical-hint ambiguity warnings, registered resource metadata, and duplicate local resource names. `--descendants` follows registered children and also checks route cycles, deterministic nearest-scope skill shadowing, cross-sibling resource references, and confidential-sibling co-location. A descendant may own a same-named skill and replaces the ancestor declaration for its subtree; validation reports both paths as a warning. It does not require reciprocity because children have no parent declaration.

## Generate or check platform adapters

```bash
ruby "${SETUP_AGENTIC_SCOPE_SKILL_DIR}/scripts/scope_tool.rb" adapters \
  --scope initiatives/atlas/AGENTS.md
```

This generates only thin platform mechanics: a Claude import and local skill link, a scoped Cursor rule, and a repository-wide or path-specific Copilot pointer. Codex uses canonical files directly. The command is idempotent, repairs stale managed adapters, and refuses to overwrite unmanaged files. Use `--dry-run`, `--check`, or `--platforms codex,claude,cursor,copilot` as needed.

## Safety rules

- Resolve every declared path from the `AGENTS.md` that declares it.
- Keep each scope independently usable; never add parent knowledge or dependencies to a child.
- Route downward only through explicit child entries and verify the selected child header.
- Ask for clarification when several hints plausibly match; do not enumerate every child body.
- Never enumerate siblings or descendants outside an explicit candidate container or registered route.
- Keep skill names unique within each scope. When a descendant intentionally reuses an ancestor skill name, the nearest declaration to the active scope is effective and validation reports the shadowed path.
- Treat `.agents/local/` as optional and private by convention, not as a secrets vault.
- Treat generated platform files as disposable adapters; durable knowledge belongs in canonical maps and resources.

## Requirements

- Ruby 2.6 or newer with standard-library `yaml`, `json`, `optparse`, `pathname`, and `tempfile`.
- Scope maps follow `.agents/context/progressive-disclosure.md`.
