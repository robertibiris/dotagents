# Child-Scope Routing Experiment

This experiment compares two one-way parent-to-child scope registries with twenty identical child scopes:

- paths only;
- paths plus concise, parent-owned `when` routing hints.

The child maps remain authoritative about their own names and descriptions. A routing hint describes the relationship between one parent and one child; it does not replace child-header verification.

Blind Codex sessions receive the same routing protocol, prompt suite, output schema, model, permissions, and child content. Fixture directory names (`cobalt` and `umber`) intentionally do not reveal their semantics to tested agents.

## Generate isolated fixtures

```bash
ruby generate_fixtures.rb --output /private/tmp/scope-child-routing-fixtures
```

The generator refuses to overwrite an existing output directory. Each generated variant is an independent Git repository so Codex does not inherit this template repository's instructions.

## Evaluation priorities

1. Correct routing and appropriate clarification.
2. Verification of every selected child header.
3. No reads beyond child frontmatter and no unrelated sibling-body disclosure.
4. Tokens and tool calls per successful compliant route.

The first pass is a paired 28-prompt pilot. Repeat only unstable or decision-critical categories before drawing a final conclusion.
