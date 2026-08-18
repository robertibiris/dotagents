# Alternative B: Native Platform Hierarchy

Borealis Group relies on each platform's supported discovery mechanisms instead of defining a platform-neutral traversal algorithm.

- Every scope has an `AGENTS.md` containing only instructions for that scope.
- Every scope has its own `.agents/context/` and `.agents/skills/`.
- Every scope has a `CLAUDE.md` and a `.claude/skills` link for Claude Code.
- Every scope has a nested `.cursor/rules/` rule for Cursor.
- The company root has repository-wide and path-specific GitHub Copilot instructions.
- Codex consumes the `AGENTS.md` and `.agents/skills/` hierarchy directly.

Unlike Alternative A, child nodes do not contain parent pointers or a traversal algorithm. Successful inheritance depends on the platform and the directory from which it is launched.

See [`TESTING.md`](TESTING.md) for the experiment procedure.
