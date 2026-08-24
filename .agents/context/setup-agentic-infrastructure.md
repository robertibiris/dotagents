---
name: setup-agentic-infrastructure
description: Operational guide for installing, composing, migrating, and verifying shared agentic infrastructure and optional developer-local state.
---

# Setup Agentic Infrastructure

This guide installs the architecture defined by `agentic-infrastructure.md` and `progressive-disclosure.md`. Platform integrations are described in `platform-adapters.md`.

## Choose an Independent Scope

Before creating files, decide:

- What does this scope represent, and where does it live?
- Which context and skills does it own?
- Does it need optional `.agents/local/` state?
- Will a broader entry scope register it as a direct child?
- Which platforms must operate when this scope is opened independently?

Context scopes and Git repositories are independent design choices. One repository may hold many scopes; one standalone repository may be registered by several broader entries.

## Minimum Shared Structure

```text
scope/
├── AGENTS.md
└── .agents/
    ├── context/   # only when used
    └── skills/    # only when used
```

## Create the Scope Map

The lean frontmatter registry requires only identity metadata:

```yaml
---
name: example-project
description: Independent scope for Example Project implementation and delivery.
---
```

Add optional fields only when used:

```yaml
---
name: example-workspace
description: Shared entry scope for a portfolio of independent initiatives.
type: workspace
children:
  - path: initiatives/example-project/AGENTS.md
    when: Use for Example Project implementation, delivery, or its services.
resources:
  context:
    - .agents/context/operating-model.md
  skills:
    - .agents/skills/portfolio-review/SKILL.md
---
```

`type` and `confidential` are optional top-level annotations. `children` and `resources` are optional. All registered paths resolve from the directory containing the declaring `AGENTS.md`.

Keep the body concise: local instructions, protected requirements owned by this scope, and navigation behavior. Do not duplicate registered resource bodies or child details.

## Register Local Context and Skills

Every registered agent-addressable Markdown file begins with:

```yaml
---
name: example-architecture
description: Architecture boundaries and component relationships for Example Project.
---
```

Add context paths to `resources.context` and skill entry paths to `resources.skills`. Registration—not directory membership—makes a resource discoverable. Keep skill-owned templates and deterministic scripts inside the skill directory. Skill names must be unique within one scope. An independently usable descendant may reuse an ancestor skill name; along that descendant's route, the nearest declaration is effective and validation emits a shadowing warning with both paths.

## Compose a Parent Entry from Children

Composition is one-way:

1. Create and validate the child as an independent scope.
2. Add `{path, when}` to the broader entry's `children` array.
3. Keep `when` as short as possible while clearly explaining when to inspect that child.
4. Verify the selected child's authoritative `name` and `description` before entering it.
5. Register only direct children; each child may register its own direct children.

Use `setup-agentic-scope register-child` to update only the parent map. Never add a parent pointer or parent-owned dependency to the child. The same child may be registered by several parents without modification.

When several hints plausibly match a request, ask for clarification. Do not inspect every child body. A child that is opened independently has only its own context; broader context is available only when a session begins at or explicitly selects the broader entry.

## Optional Local Directory

Create `.agents/local/` only when the scope owns developer-local context, experimental skills, tracked plans, scratch work, or independent local history:

```text
.agents/local/
├── README.md
├── context/.gitkeep
├── skills/.gitkeep
└── plans/.gitkeep
```

The active scope is the only implicit owner. If work was composed from a broader entry and another scope on that route should own local state, select it explicitly. Never fall back silently to a broader scope's local directory. Run `setup-local-repo` when the directory should become a nested Git repository. Local state is private by convention, not a secrets vault.

## Add Platform Integrations

Follow `platform-adapters.md` and generate only the adapters required by chosen platforms. Adapters point to canonical scope material and never copy business or project knowledge.

Resolve the adapter command from the discovered skill directory:

```bash
ruby "${SETUP_AGENTIC_SCOPE_SKILL_DIR}/scripts/scope_tool.rb" adapters \
  --scope path/to/AGENTS.md
```

Use `--dry-run` before changing an unfamiliar installation and `--check` for read-only verification.

## Migrate Existing Infrastructure

### Flat installation

A flat project is already an independent one-scope installation:

1. Add conforming `name` and `description` frontmatter to root `AGENTS.md`.
2. Review and register context and skills individually.
3. Add metadata to every registered agent-addressable Markdown file.
4. Preserve `.agents/local/` and tracked-plan locations.
5. Regenerate adapters and validate the scope.

### Legacy bidirectional hierarchy

The old schema is not supported:

1. Remove the enclosing `scope` mapping and every child-side `parent` pointer.
2. Move useful `scope.type` and `scope.confidential` values to top-level fields.
3. Convert each parent child path to an object with `path` and a concise `when` hint.
4. Confirm every former child operates correctly when its repository or directory is opened alone.
5. Register each child from every intended broader entry; do not mutate the child.
6. Resolve local ownership explicitly and remove all ancestor-local fallback assumptions.
7. Regenerate adapters and run descendant validation from each composition entry.

### Reviewable migration sequence

1. Work on a feature branch in each outer repository and record current maps, adapters, symlinks, and status.
2. Preview setup, registration, and adapter changes with `--dry-run`.
3. Preserve existing `AGENTS.md` bodies while migrating frontmatter.
4. Validate independent scopes first, then every intended composed route.
5. Run tool, adapter, and local-repository regression tests.
6. Commit canonical infrastructure separately from developer-owned local-plan progress when the repositories are independent.

### Rollback

- Restore changed outer-repository files from the feature branch or reviewed backup.
- Remove only newly generated files carrying the `Generated by setup-agentic-scope` marker.
- Undo parent registrations without changing independent children.
- Never delete, reset, or move an existing `.agents/local/.git/`; its history is independent.

## Migrate the Legacy Plans Repository

For a project upgrading from the former `.agents/plans/` nested repository, resolve and run `migrate_legacy_plans_repo.sh` from the discovered `setup-local-repo` skill directory. The migration preserves Git history and moves plans beneath `.agents/local/plans/`.

## Verify

- [ ] Every scope works independently with only `name` and `description` required.
- [ ] Every child registration contains a valid path and concise routing hint.
- [ ] Children contain no parent pointers or parent-dependent resources.
- [ ] Registered resources exist and expose valid discovery metadata.
- [ ] Registered paths resolve from their declaring scope.
- [ ] Routing follows only explicit direct-child entries and verifies selected child headers.
- [ ] Ambiguous hints trigger clarification instead of broad disclosure.
- [ ] Skill names are unique within each scope; intentional descendant shadowing is deterministic and its validator warnings have been reviewed.
- [ ] Platform adapters reference canonical sources without duplicated scope knowledge.
- [ ] Optional local state defaults only to its active owning scope.
- [ ] Nested repositories and multiply registered children remain independently usable.

Use `review-agentic-infra` for a complete audit. Its implementation must evolve with the normative architecture rather than treating this guide as the authority.
