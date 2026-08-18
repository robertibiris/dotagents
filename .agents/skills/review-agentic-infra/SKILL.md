---
name: review-agentic-infra
description: "Review and audit the AI agent infrastructure for a project. This infra skill performs a comprehensive review of context files, skills, and agent infrastructure scripts. Use when you want to audit the agentic setup, check for inconsistencies, verify single-source-of-truth compliance, or ensure infrastructure quality. Triggers on: 'review infrastructure', 'audit agents', 'check agentic setup', 'review agentic infra', 'audit infra', or when someone wants to verify the health of the agent infrastructure."
---

Review and audit the AI agent infrastructure. This includes context files (documentation), skills, and agent infrastructure scripts (code).

**Scope**: Agent infrastructure only (not project code/content)

## Review scope

### Context files to review:
- `AGENTS.md` (root level and in subdirectories if any)
- `.agents/` directory:
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

## Review process

### Step 1: Inventory agent infrastructure

1. **Identify all context files**: Scan for `AGENTS.md` files, list all `.md` files in `.agents/context/`, inspect `.agents/local/README.md`, and check platform-specific files.
2. **Identify all skills and assets**: List all `SKILL.md` files and their directly owned templates/scripts under `.agents/skills/`.
3. **Identify all scripts**: Find all executable or script files in shared `.agents/` infrastructure while excluding developer-local contents.
4. **Inventory path references**: Search active infrastructure for local, plan-root, template, and setup-skill references; classify historical plan records separately from operative guidance.

### Step 2: Review context files

For each context file, evaluate against:

1. **Structure & Organization** — follows `agentic-infrastructure.md`, `progressive-disclosure.md`, and `setup-agentic-infrastructure.md`; proper directory organization, clear naming, appropriate location.
2. **Content Quality** — complete, clear, actionable, with examples where helpful, correct references.
3. **Consistency** — consistent structure, naming, formatting, and style across files. Correct cross-references.
4. **Best Practices** — single source of truth (no duplication), platform files reference core context, proper separation of concerns, modular design.
5. **Maintainability** — easy to update, clear relationships, portable where applicable, logical structure.
6. **Ownership boundary** — shared guidance and assets remain outer-tracked; developer-owned state remains local and ignored.

### Step 3: Review skills

For each skill, evaluate:

1. **Frontmatter quality** — name is descriptive, description is substantive and covers triggering contexts.
2. **Instruction clarity** — instructions are clear, actionable, and well-structured.
3. **Completeness** — covers inputs, steps, quality bar, and edge cases.

### Step 4: Review scripts (if any)

For each script, evaluate: efficacy, clarity, modularity, maintainability, scalability, code quality, idempotency, preflight safety, and recovery behavior for filesystem or Git migrations.

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
