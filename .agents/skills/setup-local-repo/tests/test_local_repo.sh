#!/usr/bin/env bash
# Isolated regression checks for setup-local-repo.

set -euo pipefail

SOURCE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
SETUP_SCRIPT="${SOURCE_ROOT}/.agents/skills/setup-local-repo/scripts/setup_local_repo.sh"
MIGRATE_SCRIPT="${SOURCE_ROOT}/.agents/skills/setup-local-repo/scripts/migrate_legacy_plans_repo.sh"
TEMPLATE="${SOURCE_ROOT}/.agents/skills/setup-local-repo/templates/local-repo.gitignore.template"
TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/setup-local-repo-tests.XXXXXX")"

pass_count=0

cleanup() {
    rm -rf "${TEST_ROOT}"
}
trap cleanup EXIT

pass() {
    pass_count=$((pass_count + 1))
    printf '[PASS] %s\n' "$1"
}

fail() {
    printf '[FAIL] %s\n' "$1" >&2
    exit 1
}

write_file() {
    local path="$1"
    local content="$2"
    mkdir -p "$(dirname "${path}")"
    printf '%s\n' "${content}" > "${path}"
}

prepare_shared_files() {
    local fixture="$1"
    mkdir -p "${fixture}/.agents/local/context" "${fixture}/.agents/local/skills" "${fixture}/.agents/local/plans"
    mkdir -p "${fixture}/.agents/skills/setup-local-repo/scripts" "${fixture}/.agents/skills/setup-local-repo/templates"
    write_file "${fixture}/.agents/local/README.md" "# Local Developer Directory"
    write_file "${fixture}/.agents/local/context/.gitkeep" "# outer tracked"
    write_file "${fixture}/.agents/local/skills/.gitkeep" "# outer tracked"
    write_file "${fixture}/.agents/local/plans/.gitkeep" "# outer tracked"
    cp "${SETUP_SCRIPT}" "${fixture}/.agents/skills/setup-local-repo/scripts/setup_local_repo.sh"
    cp "${MIGRATE_SCRIPT}" "${fixture}/.agents/skills/setup-local-repo/scripts/migrate_legacy_plans_repo.sh"
    cp "${TEMPLATE}" "${fixture}/.agents/skills/setup-local-repo/templates/local-repo.gitignore.template"
}

prepare_outer_repo() {
    local fixture="$1"
    git -C "${fixture}" init -q
    git -C "${fixture}" config user.name "Local Repo Test"
    git -C "${fixture}" config user.email "local-repo-test@example.invalid"
}

prepare_legacy_repo() {
    local fixture="$1"
    mkdir -p "${fixture}/.agents/plans/demo"
    git -C "${fixture}/.agents/plans" init -q
    git -C "${fixture}/.agents/plans" config user.name "Local Repo Test"
    git -C "${fixture}/.agents/plans" config user.email "local-repo-test@example.invalid"
    write_file "${fixture}/.agents/plans/.gitignore" "README.md"
    write_file "${fixture}/.agents/plans/demo/plan.md" $'# Plan: Demo\n\nstatus: active'
    git -C "${fixture}/.agents/plans" add .gitignore demo/plan.md
    git -C "${fixture}/.agents/plans" commit -qm "Initial legacy plan"
}

test_fresh_and_repeated_setup() {
    local fixture="${TEST_ROOT}/fresh"
    mkdir -p "${fixture}"
    prepare_outer_repo "${fixture}"
    prepare_shared_files "${fixture}"

    (cd "${fixture}" && bash .agents/skills/setup-local-repo/scripts/setup_local_repo.sh >/dev/null)
    [[ -d "${fixture}/.agents/local/.git" ]] || fail "fresh setup did not create local repository"
    cmp -s "${fixture}/.agents/local/.gitignore" "${TEMPLATE}" || fail "fresh setup .gitignore differs from template"
    [[ "$(git -C "${fixture}/.agents/local" rev-list --count HEAD)" == "1" ]] || fail "fresh setup did not create one initial commit"

    (cd "${fixture}" && bash .agents/skills/setup-local-repo/scripts/setup_local_repo.sh >/dev/null)
    [[ "$(git -C "${fixture}/.agents/local" rev-list --count HEAD)" == "1" ]] || fail "repeat setup created another commit"
    pass "fresh and repeated setup"
}

test_resume_incomplete_setup() {
    local fixture="${TEST_ROOT}/partial"
    mkdir -p "${fixture}"
    prepare_outer_repo "${fixture}"
    prepare_shared_files "${fixture}"
    git -C "${fixture}/.agents/local" init -q

    (cd "${fixture}" && bash .agents/skills/setup-local-repo/scripts/setup_local_repo.sh >/dev/null)
    git -C "${fixture}/.agents/local" rev-parse --verify HEAD >/dev/null || fail "partial setup did not resume to a commit"
    pass "incomplete setup recovery"
}

test_explicit_scope_from_outside() {
    local fixture="${TEST_ROOT}/explicit-scope/company/client"
    mkdir -p "${fixture}"
    prepare_outer_repo "${fixture}"
    prepare_shared_files "${fixture}"

    (cd "${TEST_ROOT}" && bash "${fixture}/.agents/skills/setup-local-repo/scripts/setup_local_repo.sh" --scope-dir "${fixture}" >/dev/null)
    [[ -d "${fixture}/.agents/local/.git" ]] || fail "explicit scope setup targeted the process working directory"
    pass "explicit context-scope setup from another working directory"
}

test_history_migration_with_dirty_content() {
    local fixture="${TEST_ROOT}/migration"
    mkdir -p "${fixture}"
    prepare_outer_repo "${fixture}"
    prepare_shared_files "${fixture}"
    prepare_legacy_repo "${fixture}"

    git -C "${fixture}/.agents/plans" branch topic
    local old_head old_refs old_count
    old_head="$(git -C "${fixture}/.agents/plans" rev-parse HEAD)"
    old_refs="$(git -C "${fixture}/.agents/plans" for-each-ref --format='%(refname) %(objectname)' | sort)"
    old_count="$(git -C "${fixture}/.agents/plans" rev-list --count --all)"
    write_file "${fixture}/.agents/plans/demo/plan.md" $'# Plan: Demo\n\nstatus: active\nupdated: dirty'
    write_file "${fixture}/.agents/plans/untracked/plan.md" $'# Plan: Untracked\n\nstatus: pending'
    write_file "${fixture}/.agents/local/context/private.md" "developer context"

    (cd "${fixture}" && bash .agents/skills/setup-local-repo/scripts/migrate_legacy_plans_repo.sh >/dev/null)

    [[ -d "${fixture}/.agents/local/.git" && ! -d "${fixture}/.agents/plans/.git" ]] || fail "Git metadata was not re-rooted"
    [[ -f "${fixture}/.agents/local/plans/demo/plan.md" ]] || fail "tracked plan was not migrated"
    [[ -f "${fixture}/.agents/local/plans/untracked/plan.md" ]] || fail "untracked plan was not preserved"
    [[ -f "${fixture}/.agents/local/context/private.md" ]] || fail "existing local content was not preserved"
    [[ "$(git -C "${fixture}/.agents/local" rev-parse HEAD)" == "${old_head}" ]] || fail "HEAD changed during migration"
    [[ "$(git -C "${fixture}/.agents/local" rev-list --count --all)" == "${old_count}" ]] || fail "commit count changed during migration"
    [[ "$(git -C "${fixture}/.agents/local" for-each-ref --format='%(refname) %(objectname)' | sort)" == "${old_refs}" ]] || fail "refs changed during migration"
    git -C "${fixture}/.agents/local" diff --cached --quiet && fail "migration changes were not staged for review"
    pass "history migration with dirty, untracked, and existing local content"
}

test_collision_refusal() {
    local fixture="${TEST_ROOT}/collision"
    mkdir -p "${fixture}"
    prepare_outer_repo "${fixture}"
    prepare_shared_files "${fixture}"
    prepare_legacy_repo "${fixture}"
    mkdir -p "${fixture}/.agents/local/plans/demo"

    if (cd "${fixture}" && bash .agents/skills/setup-local-repo/scripts/migrate_legacy_plans_repo.sh >/dev/null 2>&1); then
        fail "migration accepted a destination collision"
    fi
    [[ -d "${fixture}/.agents/plans/.git" ]] || fail "collision failure mutated legacy repository"
    pass "destination collision refusal"
}

test_existing_local_repo_refusal() {
    local fixture="${TEST_ROOT}/existing-local"
    mkdir -p "${fixture}"
    prepare_outer_repo "${fixture}"
    prepare_shared_files "${fixture}"
    prepare_legacy_repo "${fixture}"
    git -C "${fixture}/.agents/local" init -q

    if (cd "${fixture}" && bash .agents/skills/setup-local-repo/scripts/migrate_legacy_plans_repo.sh >/dev/null 2>&1); then
        fail "migration accepted an existing local repository"
    fi
    [[ -d "${fixture}/.agents/plans/.git" ]] || fail "existing-local failure mutated legacy repository"
    pass "existing local repository refusal"
}

test_missing_identity_failure() {
    local fixture="${TEST_ROOT}/missing-identity"
    mkdir -p "${fixture}"
    git -C "${fixture}" init -q
    prepare_shared_files "${fixture}"

    if (cd "${fixture}" && GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null bash .agents/skills/setup-local-repo/scripts/setup_local_repo.sh >/dev/null 2>&1); then
        fail "fresh setup accepted missing Git identity"
    fi
    [[ ! -d "${fixture}/.agents/local/.git" ]] || fail "identity failure initialized a repository"
    pass "missing Git identity failure before mutation"
}

test_fresh_and_repeated_setup
test_resume_incomplete_setup
test_explicit_scope_from_outside
test_history_migration_with_dirty_content
test_collision_refusal
test_existing_local_repo_refusal
test_missing_identity_failure

printf 'Completed %s local-repository regression checks.\n' "${pass_count}"
