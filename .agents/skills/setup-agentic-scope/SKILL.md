---
name: setup-agentic-scope
description: "Create, register, inspect, repair, and validate hierarchical agentic context scopes. Use when adding a company, client, project, service, package, or other scoped AGENTS.md; linking a scope to its direct parent; registering direct children, context, or skills; inspecting metadata without loading bodies; finding unregistered candidates in an explicitly selected container; or creating optional scope-local .agents/local/ state."
---

# Setup Agentic Scope

Use the bundled scope tool so navigation and registration remain deterministic. Read the normative files registered by the active root `AGENTS.md` only when an architectural decision is required.

Set `SETUP_AGENTIC_SCOPE_SKILL_DIR` to the absolute directory containing this discovered `SKILL.md`, then resolve `scripts/scope_tool.rb` beneath it. An inherited skill may live in an ancestor scope; never assume the process working directory contains the tool.

## Create or repair a scope

```bash
ruby "${SETUP_AGENTIC_SCOPE_SKILL_DIR}/scripts/scope_tool.rb" setup \
  --scope-dir clients/aster-labs \
  --name aster-labs \
  --description "Client scope for Aster Labs engagements and projects." \
  --type client \
  --parent ../../AGENTS.md
```

Add `--with-local` only when the scope needs developer-owned state. Add `--dry-run` to preflight and show planned changes without writing.
Add `--confidential` when the scope should participate in audit warnings about confidential siblings sharing a readable repository. This classification does not grant or restrict filesystem access.

Register existing local resources during creation or repair with repeatable options:

```bash
ruby "${SETUP_AGENTIC_SCOPE_SKILL_DIR}/scripts/scope_tool.rb" setup \
  --scope-dir clients/aster-labs \
  --context .agents/context/client.md \
  --skill .agents/skills/aster-engagement-review/SKILL.md
```

The setup operation validates maps and registered resource headers before mutation, preserves existing bodies, registers both sides when the parent is accessible, writes through a rollback-capable transaction, and reports a boundary when the intended parent is unavailable.

## Inspect progressive metadata

```bash
ruby "${SETUP_AGENTIC_SCOPE_SKILL_DIR}/scripts/scope_tool.rb" inspect \
  --scope clients/aster-labs/AGENTS.md \
  --include map,resources,parent,children,chain \
  --format json
```

Inspection reads frontmatter only. It returns `declared_by`, `declared_path`, `resolved_path`, and `body_loaded: false` so path provenance cannot be lost.
`--include chain,resources` returns the active scope's resources plus chain maps; it does not eagerly aggregate every ancestor resource. Inspect the chain first, select a relevant ancestor by its map description, then inspect that ancestor map with `--include resources`.

## Resolve the active scope and local directory

```bash
ruby "${SETUP_AGENTIC_SCOPE_SKILL_DIR}/scripts/scope_tool.rb" resolve \
  --start path/inside/the/work \
  --format json
```

Resolution finds the nearest applicable `AGENTS.md`, follows only declared parent pointers, and reports every accessible `.agents/local/` candidate. It selects the active scope's local directory when present, or the only applicable ancestor local directory. If several ancestor locals remain possible, it exits with ambiguity instead of guessing; rerun with `--local path/to/.agents/local` after the user or operation identifies the intended owner.

## Find candidate direct children

Candidate discovery requires explicitly selected containers and scans only their immediate subdirectories:

```bash
ruby "${SETUP_AGENTIC_SCOPE_SKILL_DIR}/scripts/scope_tool.rb" candidates \
  --scope AGENTS.md \
  --under clients
```

The command reports registered and unregistered candidates but never modifies either map. Review candidates, then use `setup` to register the intended child.

## Validate a scope

```bash
ruby "${SETUP_AGENTIC_SCOPE_SKILL_DIR}/scripts/scope_tool.rb" validate \
  --scope clients/aster-labs/AGENTS.md \
  --format text
```

Validation checks schema, registered resource metadata, parent-child reciprocity, cycles, and duplicate skill names across the accessible ancestor chain. Add `--descendants` to traverse only the registered child tree and detect duplicate child identifiers, cross-sibling resource references, and confidential-sibling co-location warnings. A missing ancestor is a boundary warning; malformed accessible infrastructure is an error.

## Generate or check platform adapters

```bash
ruby "${SETUP_AGENTIC_SCOPE_SKILL_DIR}/scripts/scope_tool.rb" adapters \
  --scope clients/aster-labs/AGENTS.md
```

This generates only thin platform mechanics: a Claude instruction import and skill symlink, a scoped Cursor rule, and a repository-wide or path-specific Copilot instruction. Codex uses the canonical hierarchy directly. The command is idempotent, repairs stale managed adapters, and refuses to overwrite unmanaged files.

Use `--dry-run` to preview, `--check` for read-only validation, or `--platforms codex,claude,cursor,copilot` to select platforms.

## Safety rules

- Resolve registered paths from their declaring `AGENTS.md`.
- Stop at inaccessible ancestors without requesting broader access automatically.
- Never enumerate siblings or descendants outside an explicit `--under` container.
- Keep skill names unique across an effective chain.
- Treat `.agents/local/` as optional and private by convention, not as a secrets vault.
- Review `--dry-run` output before modifying unfamiliar or dirty scope maps.
- Treat generated platform files as disposable adapters; put durable knowledge only in `AGENTS.md` and registered `.agents/` resources.

## Requirements

- Ruby 2.6 or newer with standard-library `yaml`, `json`, `optparse`, `pathname`, and `tempfile`.
- Scope maps follow `.agents/context/progressive-disclosure.md`.
