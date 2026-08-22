---
name: review-agentic-infra
description: "Review and audit the AI agent infrastructure for a project. This infra skill performs a comprehensive review of context files, skills, and agent infrastructure scripts. Use when you want to audit the agentic setup, check for inconsistencies, verify single-source-of-truth compliance, or ensure infrastructure quality. Triggers on: 'review infrastructure', 'audit agents', 'check agentic setup', 'review agentic infra', 'audit infra', or when someone wants to verify the health of the agent infrastructure."
---

Review and audit the AI agent infrastructure. This includes context files (documentation), skills, and agent infrastructure scripts (code).

**Scope**: Agent infrastructure only (not project code/content)

## Review scope

### Context files to review:
- The explicitly selected active `AGENTS.md` and scope maps reachable through its declared parent/direct-child registry
- Each participating scope's `.agents/` directory:
  - `context/*.md` — all context files
  - `skills/*/SKILL.md` — all skill definitions
  - `local/README.md` — purpose, privacy boundary, ownership, and optional nested version control
- `.cursor/` directory (if exists):
  - `rules/*.mdc`
- `.github/copilot-instructions.md` (if exists)
- `CLAUDE.md` (if exists)

### Agent infrastructure scripts to review:
- All scripts in `.agents/` directory (any language)
- Scripts that are part of agent workflows/automation

### Local-boundary checks:
- Verify the outer `.gitignore` ignores developer-owned `.agents/local/` content while preserving only the shared README and placeholders.
- Verify the nested `.gitignore` template ignores those outer-tracked scaffold files.
- Verify plan workflows use `.agents/local/plans/` and templates live with their consuming skills.
- Verify `setup-local-repo` documents fresh setup and safe migration behavior.
- Search active infrastructure for stale references to superseded roots, setup skills, or shared template directories.

**Out of scope**: Project code files, project documentation (unless agent context), regular project files, and the developer-owned contents of `.agents/local/` beyond its shared README, placeholders, ignore boundary, and repository structure.

## Resolve review boundaries

Run the `resolve` command bundled with `setup-agentic-scope` from the operation's working path, or use a scope explicitly named by the user. Do not substitute the nearest Git root for the context scope. If several local directories are applicable, audit shared infrastructure first and ask which local owner is intended before inspecting plan state.

Repository and filesystem permissions are the confidentiality boundary. Scope validation can prove routing consistency and detect suspicious references; it cannot prove that readable sibling content is inaccessible.

## Review process

### Step 1: Inventory agent infrastructure

1. **Identify scope maps deterministically**: Read the active map's frontmatter, then traverse only declared parents and registered direct children. Queue each registered child map; do not recursively search the filesystem for `AGENTS.md` files. Use explicit candidate containers only when the user asks to find unregistered scopes.
2. **Inspect metadata first**: Extract headers from registered context and skills without bodies. Select bodies for review only after their descriptions establish relevance to infrastructure quality.
3. **Identify skills and assets**: From each selected scope, inspect registered `SKILL.md` files and their directly owned templates/scripts. Directory membership alone does not register a resource.
4. **Identify scripts**: Inspect scripts owned by selected registered skills while excluding developer-local contents.
5. **Inventory platform adapters and path references**: Check generated adapters, declaring-scope provenance, local/plan roots, templates, and setup-skill references; classify historical plan records separately from operative guidance.
6. **Validate the registered tree**: Run `scope_tool.rb validate --scope path/to/AGENTS.md --descendants`, then run `adapters --check` at each participating scope whose platforms are supported.

### Step 2: Review context files

For each context file, evaluate against:

1. **Structure & Organization** — follows `agentic-infrastructure.md`, `progressive-disclosure.md`, and `setup-agentic-infrastructure.md`; proper directory organization, clear naming, appropriate location.
2. **Content Quality** — complete, clear, actionable, with examples where helpful, correct references.
3. **Consistency** — consistent structure, naming, formatting, and style across files. Correct cross-references.
4. **Best Practices** — single source of truth (no duplication), platform files reference core context, proper separation of concerns, modular design.
5. **Maintainability** — easy to update, clear relationships, portable where applicable, logical structure.
6. **Ownership boundary** — shared guidance and assets remain outer-tracked; developer-owned state remains local and ignored.
7. **Hierarchy integrity** — reciprocal routes, cycles, duplicate effective skill names, cross-sibling references, partial-access boundaries, and adapter integrity are reported distinctly.

### Step 3: Review skills

For each skill, evaluate:

1. **Frontmatter quality** — name is descriptive, description is substantive and covers triggering contexts.
2. **Instruction clarity** — instructions are clear, actionable, and well-structured.
3. **Completeness** — covers inputs, steps, quality bar, and edge cases.

### Step 4: Review scripts (if any)

For each script, evaluate: efficacy, clarity, modularity, maintainability, scalability, code quality, idempotency, preflight safety, and recovery behavior for filesystem or Git migrations.

### Step 5: Review isolation signals

- Treat a cross-sibling registered resource reference as a structural error.
- When multiple direct children explicitly marked confidential share one readable Git repository, report a warning for deliberate review, not a proven security defect.
- Treat missing ancestors as access-boundary warnings when the accessible subtree is otherwise valid.
- Report ambiguous `.agents/local/` ownership and do not inspect or mutate developer plan contents until resolved.

## Output format

Produce a structured review report:

### Section 1: Overview
- Summary of agent infrastructure state
- Files reviewed (context files, skills, scripts)
- High-level assessment, key strengths, key concerns

### Section 2: Context files review
- Structure & organization findings
- Content quality issues
- Consistency issues
- Best practices adherence
- Maintainability assessment
- File-specific recommendations
- Local-directory purpose, privacy, and ownership findings

### Section 3: Skills review
- Frontmatter quality assessment
- Instruction clarity findings
- Completeness assessment
- Skill-specific recommendations
- Template ownership and setup/migration safety findings
- Active-scope resolution, registered-tree validation, and platform-adapter findings

### Section 4: Action items
- **Priority 1 (Critical)**: Must-fix issues
- **Priority 2 (Important)**: Significant improvements
- **Priority 3 (Nice to Have)**: Long-term enhancements
- **Quick Wins**: Easy improvements with high impact

## Guidance

- Be thorough: review all agent infrastructure files systematically.
- Be constructive: provide actionable suggestions, not just criticism.
- Prioritize: focus on most impactful improvements first.
- Reference authority: use `agentic-infrastructure.md` and `progressive-disclosure.md` for normative behavior, `setup-agentic-infrastructure.md` for operations, and `platform-adapters.md` for platform mappings.
- Be specific: provide concrete examples and file references.
- Balance: don't over-engineer, but ensure quality and maintainability.
