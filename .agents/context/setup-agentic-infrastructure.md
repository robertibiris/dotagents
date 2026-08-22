---
name: setup-agentic-infrastructure
description: Operational guide for installing, migrating, and verifying shared agentic infrastructure and optional developer-local state.
---

# Setup Agentic Infrastructure

This guide installs the agentic infrastructure defined by `agentic-infrastructure.md` and `progressive-disclosure.md`. Platform integrations are described separately in `platform-adapters.md`.

## Choose the Initial Scope

Before creating files, identify the first context scope:

- What does the scope represent?
- Where is its directory?
- Does it have an accessible direct parent?
- Which direct children already exist?
- Which context and skills should be registered locally?
- Does this scope need optional `.agents/local/` state?
- Which agent platforms must operate here?

Do not infer that a Git repository root is necessarily the context root. A new flat project commonly starts with one root scope, but later scopes may exist inside the same repository or across nested repositories.

## Minimum Shared Structure

```text
scope/
├── AGENTS.md
└── .agents/
    ├── context/
    └── skills/
```

Create `.agents/context/` or `.agents/skills/` only when the scope owns registered resources in that category.

## Create the Scope Map

Use `AGENTS.md` frontmatter as the machine-readable registry:

```yaml
---
name: example-project
description: Project scope for Example Project implementation and delivery workflows.
scope:
  type: project
  parent: ../../AGENTS.md
  children: []
resources:
  context:
    - .agents/context/architecture.md
  skills:
    - .agents/skills/release-check/SKILL.md
---
```

All paths resolve from the directory containing the declaring `AGENTS.md`. Root scopes use `parent: null`. Generated maps use empty arrays for empty registries.

The body of `AGENTS.md` should remain a concise local map: describe local instructions, protected requirements, resource categories, and navigation behavior without duplicating registered bodies or descendant details.

## Add Registered Context

Create focused files under `.agents/context/` or register an existing project document. Newly standardized files begin with:

```yaml
---
name: example-architecture
description: Architecture boundaries and component relationships for Example Project.
---
```

Add the path to `resources.context` in the local scope map. Registration, not directory membership, makes the document part of progressive discovery.

## Add Registered Skills

Each shared repeatable workflow lives in its own `.agents/skills/{skill-name}/` directory with `SKILL.md`. Skill-owned templates and deterministic scripts remain inside that skill directory.

Add the `SKILL.md` path to `resources.skills` in the local scope map. Skill names must remain unique across an effective ancestor chain until explicit shadowing semantics are introduced.

## Register Parent and Child Scopes

For a non-root scope:

1. Set `scope.parent` to the direct parent's `AGENTS.md` using a path relative to the child map.
2. Add the child map path to the parent's `scope.children` list using a path relative to the parent map.
3. Inspect only the two map headers and verify the relationship in both directions.
4. Do not register grandchildren at the parent.

If the parent is unavailable in the current workspace, create the child with its intended parent pointer and record that reciprocal registration is pending. Runtime traversal must stop cleanly until the parent becomes accessible.

Use the `setup-agentic-scope` skill to automate and validate this operation. Its setup command preflights accessible endpoints, preserves existing map bodies, updates both declarations through a rollback-capable transaction, and reports unavailable parents as boundaries.

## Optional Local Directory

Create `.agents/local/` only when the scope needs developer-owned context, experimental skills, tracked plans, scratch work, or independent local history.

The current flat-project scaffold contains:

```text
.agents/local/
├── README.md
├── context/.gitkeep
├── skills/.gitkeep
└── plans/.gitkeep
```

Outer ignore rules preserve the scaffold while ignoring developer-owned contents. Run the `setup-local-repo` skill when this local directory should become a nested Git repository. Local state is private by convention, not a secrets vault.

When several applicable scopes contain `.agents/local/`, choose through the active scope or an explicit target. Never silently select a local directory based only on the nearest Git root.

## Add Platform Integrations

Follow `platform-adapters.md`. Create only the adapters required by the chosen platforms. Adapters reference canonical scope material and must not copy company, client, or project knowledge. Generate or repair them with `setup-agentic-scope`:

```bash
ruby .agents/skills/setup-agentic-scope/scripts/scope_tool.rb adapters \
  --scope path/to/AGENTS.md
```

Use `--dry-run` before changing an unfamiliar installation and `--check` for read-only verification.

## Migrate a Flat Installation

A flat repository is already a valid one-node hierarchy.

1. Add conforming scope-map frontmatter to the root `AGENTS.md`.
2. Propose registrations from existing `.agents/context/` and `.agents/skills/` files.
3. Review the proposal instead of silently registering every discovered file.
4. Add required frontmatter to registered agent-addressable Markdown.
5. Regenerate or repair platform adapters.
6. Preserve the existing `.agents/local/` contract and tracked-plan locations.

Do not introduce child scopes until a narrower scope provides material routing or context value.

### Reviewable migration sequence

1. Work on a feature branch in the containing repository and record the current `AGENTS.md`, platform files, symlinks, and repository status.
2. Run scope setup with `--dry-run`; review every proposed parent, child, resource, adapter, and optional local path.
3. Preserve the existing `AGENTS.md` body while adding scope-map frontmatter. A flat installation remains a one-node hierarchy.
4. Register context and skills individually after reviewing their metadata; do not infer registration from directory membership.
5. Generate adapters, then run scope validation, adapter check mode, local-repository tests, and the isolated hierarchical fixture.
6. Commit canonical infrastructure separately from developer-owned local-plan progress when those repositories are independent.

### Rollback

- Before commit, restore changed outer-repository files from the feature branch or a reviewed backup. Remove only newly generated files that carry the `Generated by setup-agentic-scope` marker.
- Revert both sides of any parent/direct-child registration together; do not leave a one-sided route.
- Do not delete, reset, or move an existing `.agents/local/.git/` while rolling back outer infrastructure. Its history is independent.
- If a legacy plans-repository migration fails, use the safety snapshot path printed by `migrate_legacy_plans_repo.sh` and follow its history/refs verification before retrying.
- After rollback, rerun flat-scope validation and confirm the original platform integration still resolves its canonical files.

## Migrate the Legacy Plans Repository

For a project upgrading from the former `.agents/plans/` nested repository:

```bash
bash .agents/skills/setup-local-repo/scripts/migrate_legacy_plans_repo.sh
```

The migration preserves Git history and moves plans beneath `.agents/local/plans/`. Review the safety snapshot and staged changes before committing.

## Verify

- [ ] Every scope map has the required frontmatter and a concise body.
- [ ] Registered parent and direct-child relationships are reciprocal or explicitly pending because an endpoint is inaccessible.
- [ ] Registered resources exist and expose valid discovery metadata.
- [ ] Registered paths resolve from their declaring scope.
- [ ] No runtime workflow depends on recursive discovery of siblings or descendants.
- [ ] Skill names are unique across each effective chain.
- [ ] Platform adapters reference canonical sources without duplicated scope knowledge.
- [ ] Optional local directories have correct ownership, ignore, and privacy guidance.
- [ ] Flat repositories and partial-access subtrees stop or inherit as expected.

Use `review-agentic-infra` for a complete audit. Its implementation must evolve with the normative architecture rather than treating this operational guide as the authority.
