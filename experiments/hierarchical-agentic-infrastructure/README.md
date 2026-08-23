# Hierarchical Agentic Infrastructure Experiments

> **Archived experiment:** These fixtures document the bidirectional design evaluated before one-way scope composition was adopted. Their `scope.parent` schema is intentionally unsupported by the current tool. To reproduce the historical validator with its matching implementation, use commit `c14b97c`. For the current decision and reproducible evidence, see [`../scope-child-routing/RESULTS.md`](../scope-child-routing/RESULTS.md).

These fixtures compare three ways of making company, client, and project context available to Codex, Claude Code, Cursor, and GitHub Copilot without exposing sibling scopes by default.

They are deliberately isolated from this template's live `.agents/` infrastructure. The company names, clients, projects, context markers, and skills are fictional.

## Shared Model

Each fixture uses this hierarchy:

```text
company
└── client
    └── project
```

When an agent starts at a project leaf, the expected effective scope is:

```text
company + direct client + project
```

Sibling clients and sibling projects are not part of the effective scope. If an ancestor is outside the filesystem or workspace boundary available to the agent, traversal stops at that boundary.

This is a context-discovery boundary, not a security boundary. An agent with permission to read the entire repository can still inspect sibling files if explicitly directed to do so.

## Alternatives

### Alternative A: Explicit protocol

[`alternative-a-explicit/atlas-collective`](alternative-a-explicit/atlas-collective/) uses platform-neutral `AGENTS.md` entry points and an explicit parent/child traversal contract. Every scope describes itself, names only its direct parent and children, and lists its own context and skills. Platform adapters do no hierarchy resolution; they only direct the platform to the local `AGENTS.md`.

This alternative tests whether a documented protocol can provide predictable behavior even when a platform's native nested discovery is incomplete.

### Alternative B: Native discovery

[`alternative-b-native/borealis-group`](alternative-b-native/borealis-group/) uses the platforms' native mechanisms:

- Codex: hierarchical `AGENTS.md` and `.agents/skills/` discovery.
- Claude Code: hierarchical `CLAUDE.md` plus scope-local `.claude/skills` links.
- Cursor: nested `.cursor/rules/` adapters.
- GitHub Copilot: `AGENTS.md`, `.agents/skills/`, and path-specific `.github/instructions/` adapters.

This alternative tests how much hierarchy the platforms can supply without an explicit traversal algorithm.

### Alternative C: Registered hybrid

[`alternative-c-hybrid/northstar-holdings`](alternative-c-hybrid/northstar-holdings/) combines the successful properties of A and B:

- Explicit parent/direct-child registration and declaring-scope path provenance provide deterministic correctness.
- Metadata-only inspection preserves progressive disclosure.
- Canonical skills remain in scope-local `.agents/skills/` directories.
- Native discovery accelerates supported platforms but is not required by the structural tests.
- Thin generated adapters contain routing mechanics only.

This was the recommendation produced by the archived experiment. The later one-way composition decision supersedes it. The historical validator exercised its full chain, direct children, sibling isolation, missing ancestor, nested repository, metadata sentinel, and adapter scenarios in disposable copies.

## Success Criteria

Run a session from each selected project directory and ask:

> Report the effective scope chain, every `CONTEXT_MARKER`, and every scope-provided skill name. Report personal, system, or plugin skills separately. Do not recursively search the repository and do not open sibling scopes.

The expected results are recorded in each alternative's `TESTING.md`. A run passes when:

1. The leaf, its parent, and every accessible ancestor are reported.
2. Their context markers and skills are available.
3. Sibling markers and skills are absent unless explicitly requested.
4. Removing access to an ancestor causes discovery to stop cleanly rather than guessing its contents.
5. The agent can explain which files or platform mechanisms produced its result.

## Interpretation

Alternative A favors portability, debuggability, and explicit boundaries, at the cost of repeated bootstrap adapters and active traversal.

Alternative B favors native ergonomics and automatic discovery, at the cost of platform-specific behavior and adapters. Results should be recorded per product and surface because GitHub Copilot CLI, Copilot IDE integrations, and cloud agents do not all support identical instruction mechanisms.

Alternative C uses explicit registration as the correctness contract and native behavior as an ergonomic optimization. It carries more machine-readable metadata than B but avoids A's separate skill catalog and repeated hand-authored bootstrap logic.

## Platform References

The native fixture is based on the platform documentation available when this experiment was created:

- [Codex skills](https://developers.openai.com/codex/skills) and [Codex `AGENTS.md`](https://learn.chatgpt.com/docs/agent-configuration/agents-md)
- [Claude Code skills](https://code.claude.com/docs/en/slash-commands) and [Claude Code memory](https://code.claude.com/docs/en/memory)
- [Cursor nested rules](https://docs.cursor.com/context/rules-for-ai) and [Cursor agent skills](https://cursor.com/docs/skills)
- [GitHub Copilot CLI custom instructions](https://docs.github.com/en/copilot/how-tos/copilot-cli/customize-copilot/add-custom-instructions), [customization support matrix](https://docs.github.com/en/copilot/reference/custom-instructions-support), and [customization cheat sheet](https://docs.github.com/en/copilot/reference/customization-cheat-sheet)

Platform discovery behavior changes over time. Recheck these references when interpreting results or promoting either fixture into the template.

Live product evidence and blockers are recorded in [`PLATFORM_VALIDATION.md`](PLATFORM_VALIDATION.md).

## Initial Finding

Codex passed both full-chain fixtures. It also passed Alternative A's reduced-access test: the explicit parent pointer stopped at the missing company and retained both client and project context and skills.

In Alternative B's reduced-access test, Codex discovered the client and project instructions and skills, but loaded only the project context marker. The client `AGENTS.md` used a scope-local relative link to `.agents/context/client.md`; after native instruction merging, the model did not reliably associate that link with the client directory. This exposes a distinction between instruction/skill discovery and arbitrary context-file discovery. The native design needs either path-origin metadata, repository-root-qualified context links, or a small explicit context-resolution convention.

Alternative C resolves that failure by retaining the declaring map for every registered path. Its automated checks pass without launching any platform, then independently verify that generated adapters remain body-free and repairable. Platform sessions remain necessary for product-specific validation, but no longer define the architecture's basic correctness.
