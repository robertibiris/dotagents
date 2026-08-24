---
name: progressive-disclosure-standard
description: Metadata, registration, routing-hint, and inspection standard for discovering agent-addressable scopes and resources without eagerly reading their bodies.
---

# Progressive Disclosure Standard

This document specifies how a scope registers direct children and agent-addressable Markdown, and how tooling discovers only what an operation requires. It implements `agentic-infrastructure.md`.

## Principles

- Registration is explicit and flows from parent to child only.
- Child routing begins with concise parent-owned `when` hints.
- Authoritative child metadata is verified before entry.
- Resource metadata is read before content bodies.
- Paths retain their declaring map.
- Unselected siblings and descendants are not inspected.
- Generated catalogs are derived and disposable.

## Scope Map Frontmatter

Every new scope map contains at least:

```yaml
---
name: stable-scope-name
description: Substantive guidance explaining what this scope owns and when it is relevant.
---
```

A scope that owns resources or composes children adds only the applicable fields:

```yaml
---
name: delivery-portfolio
description: Shared delivery conventions and routes to independently usable initiatives.
type: portfolio
confidential: true
children:
  - path: initiatives/orbit/AGENTS.md
    when: Use for the Orbit migration, rollout, or production support.
resources:
  context:
    - .agents/context/delivery-standards.md
  skills:
    - .agents/skills/portfolio-review/SKILL.md
---
```

### Fields

- `name` — required stable lowercase ASCII identifier using hyphens.
- `description` — required substantive scope identity and applicability guidance.
- `type` — optional descriptive category; consumers must not branch on its value.
- `confidential` — optional classification signal for audits; never an access-control mechanism.
- `children` — optional ordered list of direct-child relationship objects.
- `children[].path` — required path to the child's `AGENTS.md`.
- `children[].when` — required concise guidance for when this parent should follow that route.
- `resources.context` — optional ordered local context paths.
- `resources.skills` — optional ordered local `SKILL.md` paths.

Missing collections are empty. Generated maps should omit unused `children` and `resources` rather than emitting empty arrays.

### Relationship metadata

`children[].when` belongs to the parent-to-child edge. It answers “When should this parent route work here?” The child's own `description` answers “What is this scope?”

The relationship hint may differ across parents that register the same child. It must not contain the child's detailed instructions or replace authoritative child verification.

### Path base

Every declared path resolves from the directory containing the declaring `AGENTS.md`. Inspection output retains both the declared path and resolved absolute path.

## Resource Frontmatter

Registered context and skill files expose at least:

```yaml
---
name: stable-resource-name
description: Enough guidance to decide when and why the resource body should be read.
---
```

Skills may keep additional Agent Skills fields. Context may add optional metadata, but consumers must not require it for basic discovery.

Ordinary Markdown is not agent-addressable merely because it exists. A file becomes registered when an accessible scope map lists it under `resources.context` or `resources.skills`.

## Deterministic Header Inspection

An inspector must:

1. Open only an explicitly targeted file or a path registered by an already inspected map.
2. Require `---` as the first line for newly standardized files.
3. Read through the next line containing exactly `---`.
4. Stop before reading or returning the body.
5. Parse the header as YAML.
6. Return errors with declaring-map and resolved-path provenance.

The inspector imposes a reasonable maximum frontmatter size and must not read the complete body to recover malformed metadata.

## Child Routing Sequence

Given a current scope map and a request:

1. Compare the request with the current scope and its direct-child `when` hints.
2. If no child applies, remain at the current scope.
3. If one child applies, inspect that child's map header.
4. Verify the child's authoritative name and description.
5. Enter the child only when verification still supports the route.
6. Repeat from that child only if a deeper descendant is required.

When several hints materially match:

1. Inspect only those plausible child headers.
2. Report the ambiguity and ask which scope or scopes are intended.
3. Do not silently choose the strongest lexical match.

When hints do not provide enough information, an inspector may batch a defensible candidate set. It must not recursively scan descendants or treat broad header inspection as the default.

## Resource Selection Sequence

For each scope on the selected route:

1. List its registered local resource paths.
2. Extract only the registered resource headers.
3. Compare names and descriptions to the operation.
4. Read the complete body only for selected resources.

Descriptions remain authoritative in resource headers. A scope map must not maintain duplicate resource summaries. Tooling may return a compact derived catalog.

## Minimum Output Records

Child discovery returns relationship and authoritative metadata together:

```json
{
  "kind": "scope",
  "name": "orbit",
  "description": "Standalone scope for the Orbit migration and runtime.",
  "routing_hint": "Use for the Orbit migration, rollout, or production support.",
  "declared_by": "/workspace/AGENTS.md",
  "declared_path": "initiatives/orbit/AGENTS.md",
  "resolved_path": "/workspace/initiatives/orbit/AGENTS.md",
  "body_loaded": false
}
```

Resource discovery returns:

```json
{
  "kind": "context",
  "name": "orbit-retention",
  "description": "Retention and deletion requirements for Orbit data.",
  "declared_by": "/workspace/initiatives/orbit/AGENTS.md",
  "declared_path": ".agents/context/retention.md",
  "resolved_path": "/workspace/initiatives/orbit/.agents/context/retention.md",
  "body_loaded": false
}
```

## Entry and Route Resolution

Without an explicit entry, the nearest applicable `AGENTS.md` defines a standalone session. With an explicit entry, tooling follows only registered child paths whose scope directories contain the selected target.

Resolution returns:

- entry scope;
- active scope;
- ordered composed route;
- local directories owned by scopes on that route;
- selected local owner, when explicit or owned by the active scope.

Resolution never climbs through undeclared parent pointers because parent pointers do not exist.

## Errors and Ambiguity

Report an error for:

- Missing or malformed frontmatter.
- Missing required identity fields.
- A child entry missing `path` or `when`.
- Duplicate child paths or direct-child names.
- A child path not pointing to `AGENTS.md`.
- A registered file that does not exist.
- A declaring-path resolution error.
- A directed child-registration cycle.
- Duplicate skill names declared within one scope.

The same child registered by different parents is valid. Similar child hints are not a schema error, but runtime routing must surface genuine ambiguity.

A descendant may register a skill with the same `name` as an ancestor because each scope must remain independently usable. Composition resolves that name from root to leaf, replacing the effective declaration at each nearer scope. Validation reports every replacement as a warning with the ancestor and descendant paths. Shadowing changes which workflow is selected; it never permits descendant instructions to weaken effective ancestor security, privacy, compliance, confidentiality, or access requirements.

## Catalogs

A tool may cache extracted metadata for efficiency. A catalog must identify its source maps, retain declaring and resolved paths, be safe to delete, and never override newer source metadata. Direct header extraction remains the baseline.

## Validation Scenarios

The implementation must test:

1. Header extraction stops before a body sentinel.
2. A relevant registered resource can be expanded separately.
3. Unregistered Markdown remains absent.
4. A routing hint selects one child without inspecting siblings.
5. Multiple plausible hints produce ambiguity.
6. A path resolves from its declaring map while execution starts elsewhere.
7. A standalone child contains no ancestor dependency.
8. The same child can be registered by two parents.
9. A nested target resolves from an explicit entry scope.
10. Missing empty collections are accepted.
11. Malformed or unterminated frontmatter fails without body loading.
12. A descendant same-named skill shadows its ancestor with a diagnostic, while duplicate names inside one scope fail.

## Migration

The bidirectional format is intentionally unsupported. Migrate it in one reviewed operation rather than maintaining dual semantics. Parent child paths require human-authored `when` hints; tooling must not invent routing intent from filenames alone.
