# Explicit Hierarchy Protocol

The closest `AGENTS.md` is the entry point for the active scope.

1. Read that scope's local sources.
2. Follow its `Parent` path to the parent's `AGENTS.md`.
3. Repeat until `Parent: none` or the next parent cannot be read.
4. Apply the collected scopes from root to leaf.
5. Use `Children` only as a routing table when a task explicitly targets a child.
6. Do not enumerate directories to discover siblings or descendants.

Each parent knows only its own details and the locations of its direct children. Each child knows only its own details, its direct parent, and its direct children.

When traversal stops because a parent is inaccessible, report the boundary. Never infer missing context or skills.
