---
name: setup-local-repo
description: "Initialize the optional nested Git repository inside .agents/local/ so developers can version-control personal context, experimental skills, tracked plans, and other local workflow state without committing it to the main repository. Also use when migrating the former .agents/plans/ nested repository into the generic local structure. Triggers on: 'setup local repo', 'initialize local repo', 'set up local version control', 'migrate plans repo', 'migrate local developer space', or 'setup developer space'."
---

Set up or migrate the optional nested repository for `.agents/local/`.

## Purpose

`.agents/local/` is the developer-owned boundary. It may contain personal context, experimental skills, tracked plans, scratch work, and private workflow state. The outer repository ignores this content while preserving a small shared scaffold.

## Implementation

The scripts in `scripts/` are the deterministic sources of truth:

- `setup_local_repo.sh` — initialize a fresh local repository.
- `migrate_legacy_plans_repo.sh` — re-root an existing `.agents/plans/.git/` repository at `.agents/local/.git/` while preserving history.

Both scripts use `templates/local-repo.gitignore.template` as the authoritative nested `.gitignore` content.
Set `SETUP_LOCAL_REPO_SKILL_DIR` to the absolute directory containing this discovered `SKILL.md`. Resolve both scripts and their template beneath it; when the skill is inherited from an ancestor, do not resolve them from the active leaf.

## Resolve the owning scope

Use the `setup-agentic-scope` resolver from the operation's working path before initialization or migration. The target is the context scope that owns the selected `.agents/local/`, not necessarily a Git root. If several ancestor local directories are applicable and the active scope has none, require an explicit scope choice. Pass that scope directory to the scripts with `--scope-dir`.

## Fresh Setup

Run with the intended context scope explicitly:

```bash
bash "${SETUP_LOCAL_REPO_SKILL_DIR}/scripts/setup_local_repo.sh" \
  --scope-dir path/to/scope
```

The script validates the scaffold and Git identity, writes the generated `.gitignore`, initializes `.agents/local/.git/`, and creates the initial local-repository commit. Re-running it after successful initialization is a no-op.

## Legacy Migration

For an existing nested repository at `.agents/plans/.git/`, run:

```bash
bash "${SETUP_LOCAL_REPO_SKILL_DIR}/scripts/migrate_legacy_plans_repo.sh" \
  --scope-dir path/to/scope
```

The migration script:

1. Refuses an existing `.agents/local/.git/` or any destination collision.
2. Records the legacy branch, `HEAD`, refs, commit count, status, and plan inventory.
3. Creates a timestamped safety snapshot under `/tmp`.
4. Moves legacy plan content beneath `.agents/local/plans/`.
5. Moves the original `.git/` directory to `.agents/local/.git/` without rewriting history.
6. Installs the new generated `.gitignore` and stages the path migration for review.
7. Verifies repository identity, history, refs, and plan-file counts.

The script does not commit the migration. Review both repositories before committing.

## Side Effects

- Fresh setup creates `.agents/local/.git/`, `.agents/local/.gitignore`, and an initial local commit.
- Legacy migration moves local plan files and the existing nested Git metadata, creates a recoverable `/tmp` snapshot, and stages changes in the re-rooted local repository.

## Safety Notes

- Do not initialize a new local repository over an existing legacy plans repository; migrate it.
- Do not use either script to combine two independent nested repositories.
- `.agents/local/` is private by convention, not a secrets vault.
- The outer and nested `.gitignore` files are complementary: the outer repository ignores developer content; the nested repository ignores outer-tracked scaffold files.
