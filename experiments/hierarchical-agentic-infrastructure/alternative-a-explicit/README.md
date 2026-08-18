# Alternative A: Explicit Hierarchy

Atlas Collective does not depend on platform-native inheritance. The active scope's `AGENTS.md` is the entry point.

At every scope, the agent must:

1. Read the local scope details, context index, and skill index.
2. Follow the direct `Parent` pointer and repeat until it reaches the root or an inaccessible boundary.
3. Never traverse a `Children` entry unless the task targets that child.
4. Never infer or search for siblings.
5. Apply ancestors from root to leaf, with the leaf winning only when instructions explicitly conflict.

Platform-specific files are thin bootstraps that point to `AGENTS.md`; they contain no company, client, or project knowledge. Skills intentionally live under the nonstandard `.agents/catalog/skills/` path so native skill scanning cannot be mistaken for success of the explicit protocol.

See [`TESTING.md`](TESTING.md) for the experiment procedure.
