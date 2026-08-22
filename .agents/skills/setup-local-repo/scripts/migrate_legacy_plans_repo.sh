#!/usr/bin/env bash
# Re-root the legacy .agents/plans nested repository at .agents/local/.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCOPE_DIR="$(pwd)"
if [[ "${1:-}" == "--scope-dir" ]]; then
    [[ -n "${2:-}" ]] || { printf '[ERROR] --scope-dir requires a path\n' >&2; exit 1; }
    SCOPE_DIR="$(cd "${2}" && pwd)"
    shift 2
fi
[[ "$#" -eq 0 ]] || { printf '[ERROR] Unknown arguments: %s\n' "$*" >&2; exit 1; }

LEGACY_DIR="${SCOPE_DIR}/.agents/plans"
LOCAL_DIR="${SCOPE_DIR}/.agents/local"
LOCAL_PLANS_DIR="${LOCAL_DIR}/plans"
TEMPLATE_PATH="${SCRIPT_DIR}/../templates/local-repo.gitignore.template"

log_info() { printf '[INFO] %s\n' "$*"; }
log_error() { printf '[ERROR] %s\n' "$*" >&2; }

main() {
    if [[ ! -d "${LEGACY_DIR}/.git" ]]; then
        log_error "Legacy repository not found at ${LEGACY_DIR}/.git"
        exit 1
    fi
    if [[ -d "${LOCAL_DIR}/.git" ]]; then
        log_error "A local repository already exists at ${LOCAL_DIR}/.git; refusing to combine repositories."
        exit 1
    fi
    if [[ ! -d "${LOCAL_PLANS_DIR}" || ! -f "${TEMPLATE_PATH}" ]]; then
        log_error "The shared local scaffold or local .gitignore template is missing."
        exit 1
    fi

    local old_head old_branch old_commit_count old_refs old_plan_count
    old_head="$(git -C "${LEGACY_DIR}" rev-parse --verify HEAD)"
    old_branch="$(git -C "${LEGACY_DIR}" branch --show-current)"
    old_commit_count="$(git -C "${LEGACY_DIR}" rev-list --count --all)"
    old_refs="$(git -C "${LEGACY_DIR}" for-each-ref --format='%(refname) %(objectname)' | sort)"
    old_plan_count="$(find "${LEGACY_DIR}" -mindepth 2 -type f -not -path '*/.git/*' | wc -l | tr -d ' ')"

    shopt -s dotglob nullglob
    local source base target
    for source in "${LEGACY_DIR}"/*; do
        base="$(basename "${source}")"
        case "${base}" in
            .git|.gitignore|.DS_Store|_template|README.md|AGENTS.md) continue ;;
        esac
        target="${LOCAL_PLANS_DIR}/${base}"
        if [[ -e "${target}" ]]; then
            log_error "Destination collision: ${target}"
            exit 1
        fi
    done

    local backup_root
    backup_root="$(mktemp -d "${TMPDIR:-/tmp}/agent-local-migration.XXXXXX")"
    cp -a "${LEGACY_DIR}" "${backup_root}/plans-repository"
    log_info "Safety snapshot created at ${backup_root}/plans-repository"
    log_info "Legacy branch: ${old_branch:-detached}; HEAD: ${old_head}"
    git -C "${LEGACY_DIR}" status --short --branch

    for source in "${LEGACY_DIR}"/*; do
        base="$(basename "${source}")"
        case "${base}" in
            .git|.gitignore|.DS_Store|_template|README.md|AGENTS.md) continue ;;
        esac
        mv "${source}" "${LOCAL_PLANS_DIR}/${base}"
    done

    if [[ -f "${LEGACY_DIR}/.gitignore" ]]; then
        mv "${LEGACY_DIR}/.gitignore" "${LOCAL_DIR}/.gitignore"
    fi
    mv "${LEGACY_DIR}/.git" "${LOCAL_DIR}/.git"
    cp "${TEMPLATE_PATH}" "${LOCAL_DIR}/.gitignore"

    git -C "${LOCAL_DIR}" add -A

    local new_head new_branch new_commit_count new_refs new_plan_count
    new_head="$(git -C "${LOCAL_DIR}" rev-parse --verify HEAD)"
    new_branch="$(git -C "${LOCAL_DIR}" branch --show-current)"
    new_commit_count="$(git -C "${LOCAL_DIR}" rev-list --count --all)"
    new_refs="$(git -C "${LOCAL_DIR}" for-each-ref --format='%(refname) %(objectname)' | sort)"
    new_plan_count="$(find "${LOCAL_PLANS_DIR}" -mindepth 2 -type f | wc -l | tr -d ' ')"

    [[ "${new_head}" == "${old_head}" ]] || { log_error "HEAD changed during migration."; exit 1; }
    [[ "${new_branch}" == "${old_branch}" ]] || { log_error "Current branch changed during migration."; exit 1; }
    [[ "${new_commit_count}" == "${old_commit_count}" ]] || { log_error "Commit count changed during migration."; exit 1; }
    [[ "${new_refs}" == "${old_refs}" ]] || { log_error "Refs changed during migration."; exit 1; }
    [[ "${new_plan_count}" == "${old_plan_count}" ]] || { log_error "Plan-file count changed during migration (${old_plan_count} -> ${new_plan_count})."; exit 1; }

    log_info "Migration verified successfully."
    log_info "Backup: ${backup_root}/plans-repository"
    log_info "The local repository changes are staged but not committed."
    git -C "${LOCAL_DIR}" status --short --branch
}

main "$@"
