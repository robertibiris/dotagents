---
name: setup-agentic-context
description: "Set up the agentic infrastructure in a new repository: create the required files and folders (root AGENTS.md, .agents/, templates, and optional platform integrations) so AI agents and developers share a consistent, portable workflow. This is an infra skill for bootstrapping a new project or repo. Triggers on: 'setup agents', 'bootstrap infrastructure', 'set up agentic context', 'initialize agent infrastructure', 'set up infra', or when starting a new project that needs agent context."
---

Set up the agentic infrastructure in a new repository.

> Note: The terminology has evolved from "agentic context" to "agentic infrastructure." This skill name is kept for compatibility.

## Inputs

None.

## Implementation

**Architecture authority**: Follow `.agents/context/agentic-infrastructure.md` and `.agents/context/progressive-disclosure.md`.

**Operational source**: Follow the step-by-step guide in `.agents/context/setup-agentic-infrastructure.md` and the mappings in `.agents/context/platform-adapters.md`.

## Usage

1. Open `.agents/context/agentic-infrastructure.md`, `.agents/context/progressive-disclosure.md`, `.agents/context/setup-agentic-infrastructure.md`, and `.agents/context/platform-adapters.md`.
2. Choose the initial context scope independently of repository layout and follow the setup or migration steps.
3. Register local context and skills explicitly in the scope map; do not rely on directory membership alone.
4. Add only the adapters required by the chosen platforms and ensure they **reference** canonical scope material rather than duplicating it.

## Expected outcomes

- A conforming `AGENTS.md` exists at the chosen scope and acts as its canonical map.
- Registered `.agents/context/` and `.agents/skills/` resources expose progressive-disclosure metadata.
- Every scope is independently usable; broader entry scopes compose direct children through parent-owned routing hints.
- Optional `.agents/local/` state is created only when requested and may be independently versioned through `setup-local-repo`.
- Tracked plans, when enabled for the scope, live under its `.agents/local/plans/`; their templates remain with the shared skills that consume them.
- Platform adapters follow `platform-adapters.md`, preserve a single source of truth, and are validated for the chosen surface.

## Side effects

- Creates and/or updates documentation files and directories as described in the setup guide.
