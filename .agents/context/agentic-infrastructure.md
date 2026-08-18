---
name: agentic-infrastructure-architecture
description: Normative architecture for hierarchical agentic scopes, progressive context disclosure, inheritance, access boundaries, and platform adapters.
---

# Agentic Infrastructure Architecture

This document defines the canonical architecture for organizing instructions, context, skills, and developer-local state across companies, clients, projects, and other nested scopes. Operational setup steps and platform-specific mappings belong in separate documents derived from this contract.

Normative terms such as **must**, **must not**, **should**, and **may** describe requirements, recommendations, and optional behavior.

## Design Goals

The infrastructure must:

- Scale from a single project to multi-company, multi-client, and multi-project trees.
- Disclose detailed context only when an operation requires it.
- Produce deterministic navigation and path resolution.
- Work when only part of a hierarchy is accessible.
- Keep sibling scopes out of the effective context unless explicitly targeted.
- Decouple context organization from Git repository layout.
- Preserve one canonical source of truth across agent platforms.
- Distinguish contextual boundaries from actual access control.

## Core Model

### Context scope

A **context scope** is a directory where specialized agent instructions or resources are useful. A scope is defined by an `AGENTS.md` entry point and may own `.agents/` resources.

```text
scope/
├── AGENTS.md
└── .agents/
    ├── context/       # Optional registered reference documents
    ├── skills/        # Optional registered repeatable workflows
    └── local/         # Optional developer-owned state
```

A scope may represent a company, department, client, program, project, package, service, or another meaningful boundary. Scope type does not change the navigation protocol.

### Independent topologies

Three related topologies must remain conceptually independent:

- **Context topology** — the declared parent and direct-child relationships between scopes.
- **Repository topology** — the placement of Git repositories, including nested repositories.
- **Access topology** — the files and directories a particular user or agent is authorized and technically able to read.

One repository may contain several context scopes. One context hierarchy may cross nested repository boundaries. A repository exposed by itself may contain only a subtree of a larger context hierarchy.

Git roots must not be treated as universal context roots. Filesystem or workspace access must not be expanded merely because a declared context relationship exists.

## `AGENTS.md` as a Scope Map

Each `AGENTS.md` must remain a concise map of its own scope. It must provide enough information to decide where relevant knowledge can be found without embedding every detail.

A scope map must identify:

- The scope's name, description, and optional type.
- Its direct parent, or that it has no declared parent.
- Its registered direct children.
- Its registered local context resources.
- Its registered local skills.
- Any protected local instructions that descendants may not weaken.
- The path-resolution and progressive-disclosure rules, directly or through the normative architecture reference.

A parent must know only its own details and its registered direct children. It must not preload child details. A child must know only its own details, direct parent, and registered direct children.

## Progressive Disclosure

Progressive disclosure separates **awareness** of a resource from **loading** that resource.

### Discovery stages

1. **Map awareness** — read the active `AGENTS.md` map.
2. **Directional choice** — determine whether the operation needs the current scope, an ancestor, or a particular direct child.
3. **Metadata inspection** — inspect only registered resource metadata.
4. **Resource selection** — compare names and descriptions to the operation.
5. **Body expansion** — read the complete body only for selected resources.
6. **Further navigation** — follow another declared scope pointer only when the operation requires it.

Agents must not read every registered context file merely because it is visible. They must not recursively enumerate descendants or siblings to build a global catalog at runtime.

### Registered agent-addressable Markdown

The metadata requirement applies only to Markdown registered for agent use, including:

- `AGENTS.md` scope maps.
- `.agents/context/**/*.md` reference documents registered by a scope.
- `.agents/skills/*/SKILL.md` skill definitions registered by a scope.
- Agentic infrastructure reference documents.
- Tracked-plan documents governed by their existing richer metadata conventions.

Ordinary product documentation is not agent-addressable merely because it is Markdown. A scope may explicitly register an ordinary document when agents should discover it through this protocol.

Newly standardized agent-addressable Markdown must expose YAML frontmatter with at least:

```yaml
---
name: stable-resource-name
description: A substantive explanation of when and why an agent should read this resource.
---
```

Existing registered formats with richer metadata may retain their established schema when it provides equivalent identification and discovery information.

### Metadata-only inspection

Discovery tooling must be able to return a resource's path, name, and description without returning its body. Header extraction must terminate at the closing frontmatter delimiter rather than reading an arbitrary line count.

Generated indexes or catalogs may cache extracted metadata for efficiency, but they are disposable derived artifacts. Source-file metadata remains authoritative.

## Navigation Protocol

### Active scope

The **active scope** is the closest applicable scope to the operation's working location or explicitly selected target. If multiple candidate scopes are equally applicable, tooling must report ambiguity rather than choose silently.

### Ancestors

To obtain ancestor guidance:

1. Read the active scope map.
2. Follow its declared direct-parent pointer.
3. Repeat only while another ancestor is required and readable.
4. Apply gathered scope instructions from the highest accessible ancestor down to the active scope.

If a declared parent is missing or inaccessible, traversal stops. The agent must report the boundary when it materially affects the operation and must not infer the missing scope's contents.

### Children

To enter a descendant:

1. Consult only the active scope's direct-child registry.
2. Select a child whose name and description match the operation.
3. Read that child's scope map.
4. Repeat only if a deeper descendant is required.

Runtime navigation must not use recursive filesystem scanning as a substitute for registration.

### Siblings

Sibling scopes are outside the effective context by default. An agent may enter a sibling only when the operation explicitly targets it, the common parent routes to it, and access is already granted.

## Registration and Determinism

Parent and child relationships are bidirectional declarations:

- A parent registers each direct child.
- A child registers its direct parent.

Setup and repair tooling should update both declarations atomically. Validation must detect:

- A parent entry with no matching child declaration.
- A child declaration missing from its parent.
- Missing, unreadable, or malformed scope maps.
- Cycles and self-parenting.
- Duplicate child identifiers.
- Unregistered candidate scopes, reported as suggestions rather than silently added.

Explicit registration is the runtime contract. Automation maintains that contract; it does not replace it with agent judgment.

## Resource Path Semantics

Every relative resource or scope path must resolve from the directory containing the file that declares it. It must never implicitly resolve from the agent's current working directory.

Tools must retain the declaring file's path when extracting links or metadata. When an agent receives merged instructions without source-path provenance, it must use an explicit scope root or resolver rather than guess.

This rule applies to:

- Parent and direct-child pointers.
- Context and skill registrations.
- Templates, scripts, and other skill-owned assets.
- Platform adapter references.

## Inheritance and Conflicts

Instructions apply from the highest accessible ancestor to the active leaf.

Descendants may specialize general ancestor guidance for their narrower domain. They must not silently weaken instructions explicitly marked as protected, including security, privacy, compliance, confidentiality, and access-boundary requirements.

When instructions genuinely conflict and the contract does not establish precedence, the agent must surface the conflict and request direction. It must not resolve material ambiguity by guessing.

Skill names must be unique across an effective scope chain in the initial implementation. Validation must report duplicates rather than assume shadowing or merging semantics.

## Access and Confidentiality

The hierarchy controls discovery, not permission.

An agent must follow a pointer only when its existing environment permits the target to be read. It must not request broader access merely to complete the scope chain unless the user's operation independently requires that access.

Infrastructure validation must detect declared cross-sibling references. It may warn when scopes marked confidential share a repository or readable workspace, but this is not proof of a security defect: an authorized company owner may intentionally have access to multiple clients.

Repository permissions, workspace configuration, and filesystem controls remain the actual confidentiality boundary.

## Optional Local State

Any context scope may opt into `.agents/local/`. Context scopes and local repositories do not have a one-to-one relationship.

The local directory is created only when requested. It may contain personal context, experimental skills, tracked plans, scratch work, and other developer-owned state. When it is versioned as a nested repository, its ignore rules, privacy guidance, and history remain independent of the containing repository.

Tooling must not assume the repository root is the only possible local directory. If more than one applicable local directory exists, the active scope or an explicit target must determine which one is used; ambiguity must be reported.

## Platform Adapters

Canonical scope knowledge lives in `AGENTS.md` and `.agents/`. Platform-specific configuration must remain a thin adapter that references or exposes canonical material.

Native platform behavior may accelerate discovery, but correctness must not depend exclusively on it. Adapters may differ by platform and surface as long as they produce equivalent effective scope behavior.

Adapter tooling must be idempotent and should generate or repair configuration from canonical scope declarations. Developers should not need to understand symlink layouts, rule formats, or platform-specific discovery mechanics for normal use.

## Validation Requirements

A conforming validator must be able to check, without reading every context body:

- Scope-map metadata and required sections.
- Parent/direct-child reciprocity and acyclic navigation.
- Declaring-scope path resolution.
- Registered resource existence and frontmatter validity.
- Duplicate effective skill names.
- Cross-sibling resource references.
- Platform adapter integrity and source-of-truth compliance.
- Optional local-directory ownership and ignore boundaries.
- Compatibility with flat single-scope repositories.

Warnings about confidentiality co-location must remain distinguishable from structural errors.

## Required Behavioral Scenarios

Implementations must retain regression coverage for:

1. A full company → client → project chain.
2. Starting at a client and consulting a relevant company ancestor.
3. Starting at a parent and entering one explicitly selected direct child.
4. A missing or inaccessible ancestor with usable descendant scopes.
5. Multiple readable sibling scopes with no accidental sibling disclosure.
6. Several context scopes inside one repository.
7. A context chain crossing nested repository boundaries.
8. Metadata-only inspection followed by selective body loading.
9. Relative context links whose declaring scope differs from the active working directory.
10. Equivalent effective behavior through supported platform adapters.

## Compatibility and Migration

A flat repository with one root `AGENTS.md` and one root `.agents/` directory is a valid one-node hierarchy. Existing flat installations should continue working while hierarchical capabilities are added.

Migration must not require moving project documentation or local state merely to satisfy the new model. Additional scopes should be introduced only where narrower maps, context, or skills provide material value.
