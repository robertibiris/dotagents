---
name: agentic-infrastructure-architecture
description: Normative architecture for independently usable agentic scopes, one-way composition, progressive context disclosure, local ownership, access boundaries, and platform adapters.
---

# Agentic Infrastructure Architecture

This document defines the canonical architecture for organizing instructions, context, skills, and developer-local state across independently usable scopes. Operational setup and platform-specific mappings derive from this contract.

Normative terms such as **must**, **must not**, **should**, and **may** describe requirements, recommendations, and optional behavior.

## Design Goals

The infrastructure must:

- Scale from one standalone project to composed trees of portfolios, initiatives, repositories, packages, services, or other meaningful boundaries.
- Keep every scope useful without an external parent.
- Compose broader context with selected descendants without modifying those descendants.
- Disclose detailed context only when an operation requires it.
- Produce deterministic navigation and declaring-map-relative path resolution.
- Keep unselected sibling scopes out of effective context.
- Decouple context, repository, and access topologies.
- Preserve one canonical source of truth across agent platforms.
- Distinguish discovery from actual access control.

## Core Model

### Context scope

A **context scope** is a directory where specialized agent instructions or resources are useful. It is defined by an `AGENTS.md` entry point and may own `.agents/` resources:

```text
scope/
├── AGENTS.md
└── .agents/
    ├── context/       # Optional registered reference documents
    ├── skills/        # Optional registered repeatable workflows
    └── local/         # Optional developer-owned state
```

Scope categories are descriptive, not behavioral. A scope may represent a portfolio, initiative, repository, product, project, client, company, package, service, or something else. The optional `type` field must never change navigation semantics.

### Independent topologies

Three topologies remain independent:

- **Context topology** — directed parent-to-child registrations selected by an entry scope.
- **Repository topology** — Git repository placement, including nested repositories.
- **Access topology** — the files a user or agent is authorized and technically able to read.

One repository may contain several scopes. One composed context route may cross repository boundaries. The same standalone scope may be registered by several parents. Repository or filesystem permissions remain the real confidentiality boundary.

### One-way composition

Composition flows only from a parent map to its registered direct children:

```text
entry scope -> selected child -> selected grandchild
```

A child must not declare or depend on a parent. A parent may register a child without modifying it, and the same child may participate in several compositions. There is no upward traversal contract.

Two modes follow:

- **Standalone session** — begin at a scope and receive only that scope and descendants explicitly selected from it.
- **Composed session** — begin at a broader entry scope, follow one or more registered child routes required by the task, and apply the selected route from entry to target.

If broader context is required, the session must begin at or explicitly select that broader entry scope. A leaf opened independently must not attempt to discover an undeclared ancestor.

## `AGENTS.md` as a Scope Map

Each `AGENTS.md` is a concise map of its own scope. Its frontmatter provides deterministic identity, routing, and local resource registration. Its body contains instructions owned by that scope.

Minimum leaf map:

```yaml
---
name: atlas-runtime
description: Standalone scope for building and operating the Atlas runtime.
---
```

Composing map:

```yaml
---
name: product-portfolio
description: Entry scope for shared portfolio conventions and product routing.
type: portfolio
children:
  - path: products/atlas/AGENTS.md
    when: Use for Atlas product development or its production runtime.
resources:
  context:
    - .agents/context/shared-conventions.md
  skills:
    - .agents/skills/portfolio-review/SKILL.md
---
```

Only `name` and `description` are universally required. `type`, `confidential`, `children`, and `resources` may be omitted when unused. Tooling must treat missing collections as empty and must not generate empty scaffolding solely to satisfy a schema.

### Child registration

Every direct child registration contains:

- `path` — path to the child's `AGENTS.md`, resolved from the parent map.
- `when` — concise parent-owned guidance describing when this parent should route work to that child.

The routing hint describes the relationship, not the child's identity. The child remains authoritative for its own `name` and `description`. A parent must not duplicate child bodies or register grandchildren.

Routing hints are required because path-only registration was empirically shown to cause incorrect routing and costly metadata fan-out with opaque or semantically selected children. Hints should use the fewest words that reliably distinguish the route.

### Scope independence

A scope and its owned resources should stand alone. A child skill must not require a parent. A parent skill must not require a particular named child, though a generic orchestration skill may operate on a user-selected registered child through the composition contract.

## Effective Context

The **entry scope** is the deliberate starting point for a session or resolver operation. The **active scope** is the deepest selected scope relevant to the current target. The **effective route** is the ordered list from entry to active scope.

Instructions and selected resources may accumulate only along that route. Unselected children and siblings are outside effective context.

```text
portfolio -> selected initiative -> selected project
```

Opening the project independently instead produces:

```text
project
```

Descendants may specialize instructions from the composed route but must not silently weaken protected security, privacy, compliance, confidentiality, or access requirements already applied by that session.

## Progressive Disclosure

Progressive disclosure separates awareness from body loading:

1. Read the current scope map.
2. Compare the request with direct-child `when` hints and local resource metadata.
3. If no child applies, remain at the current scope.
4. If one child applies, read that child's frontmatter to verify its authoritative identity and description.
5. If several hints materially match, inspect those plausible child headers and request clarification rather than choosing silently.
6. Enter only the selected child and repeat if deeper routing is required.
7. Read complete context or skill bodies only after their metadata establishes relevance.

Agents must not recursively enumerate descendants or preload siblings. Metadata inspection may batch a defensible candidate set when hints do not fully distinguish a route, but broad inspection is a fallback rather than the default.

## Resource Ownership and Paths

`resources.context` and `resources.skills` register resources owned by the declaring scope. They never register resources owned by descendants.

Every relative path resolves from the directory containing the map or resource that declares it. Paths must never implicitly resolve from the process working directory. Inspection output must retain declaring and resolved path provenance.

Resource descriptions remain authoritative in each resource's own frontmatter. Scope maps list paths; tooling derives compact catalogs by inspecting registered headers rather than duplicating descriptions.

## Access and Confidentiality

The hierarchy controls discovery, not permission. An agent follows a registered route only when its current environment already permits that path to be read. It must not request broader access merely to complete a tree.

Sibling isolation is a runtime rule, not a security mechanism. Confidential scopes that must not be mutually visible require repository, workspace, or filesystem isolation.

## Optional Local State

Any scope may own `.agents/local/`. Context scopes and local repositories do not have a one-to-one relationship.

Local state belongs to an explicitly selected owning scope. By default, tooling selects the active scope's local directory only when it exists. It must not silently fall back to an entry or intermediate scope's local directory. A caller may explicitly select another local directory owned by the effective route.

This prevents project work from silently landing in portfolio or initiative plans while still allowing deliberate cross-scope initiatives.

## Platform Adapters

Canonical knowledge lives in `AGENTS.md` and `.agents/`. Platform-specific files are thin, disposable adapters.

Native platform discovery may accelerate local behavior, but correctness must follow the explicit entry scope and registered downward routes. Each independently opened scope may generate its own adapters. An adapter must not recreate parent links or flatten skills from several scopes.

## Validation Requirements

A conforming validator must check, without reading context or skill bodies:

- Scope-map and registered-resource metadata.
- Required `{path, when}` child entries.
- Child paths, duplicate child identifiers, and directed cycles.
- Declaring-map-relative path resolution.
- Duplicate effective skill names along each composed route.
- Cross-sibling resource references.
- Optional confidential-sibling co-location warnings.
- Platform adapter integrity.
- Optional local ownership and ignore boundaries.
- Standalone flat scopes and shared children registered by several parents.

Validation must not require child-to-parent reciprocity because no such relationship exists.

## Required Behavioral Scenarios

Implementations must retain regression coverage for:

1. A standalone one-scope repository.
2. An entry scope routing to one selected direct child by `when` hint.
3. Nested routing through direct-child maps without loading siblings.
4. A child operating independently with no ancestor knowledge.
5. The same child registered by more than one parent.
6. A context route crossing nested repository boundaries.
7. A target resolved from an explicit entry scope.
8. Metadata-only inspection followed by selective body loading.
9. Genuine child ambiguity producing clarification.
10. Local state selected from the active scope or an explicit route owner.
11. Equivalent canonical behavior through supported adapters.
12. Cycle, duplicate-skill, and cross-sibling validation failures.

## Migration

The former bidirectional schema is not supported after migration. Migrators must:

1. Remove `scope.parent` and the enclosing `scope` mapping.
2. Move optional `scope.type` and `scope.confidential` to top-level `type` and `confidential`.
3. Convert every child path into `{path, when}` after a human reviews the routing hint.
4. Preserve local resources, map bodies, local repositories, and Git history.
5. Validate each standalone scope and every intended entry tree.

A flat installation remains a valid standalone scope. Additional children should be registered only when they provide material routing or context value.
