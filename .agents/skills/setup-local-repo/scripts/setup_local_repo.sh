#!/usr/bin/env bash
# Initialize the optional nested repository in .agents/local/.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCOPE_DIR="$(pwd)"
TEMPLATE_PATH="${SCRIPT_DIR}/../templates/local-repo.gitignore.template"
if [[ "${1:-}" == "--scope-dir" ]]; then
    [[ -n "${2:-}" ]] || { printf '[ERROR] --scope-dir requires a path\n' >&2; exit 1; }
    SCOPE_DIR="$(cd "${2}" && pwd)"
    shift 2
fi
[[ "$#" -eq 0 ]] || { printf '[ERROR] Unknown arguments: %s\n' "$*" >&2; exit 1; }

LOCAL_DIR="${SCOPE_DIR}/.agents/local"
LEGACY_GIT_DIR="${SCOPE_DIR}/.agents/plans/.git"
GITIGNORE_PATH="${LOCAL_DIR}/.gitignore"
GIT_DIR="${LOCAL_DIR}/.git"

log_info() { printf '[INFO] %s\n' "$*"; }
log_error() { printf '[ERROR] %s\n' "$*" >&2; }

main() {
    if [[ ! -d "${LOCAL_DIR}" ]]; then
        log_error "${LOCAL_DIR}/ does not exist; restore the shared local scaffold first."
        exit 1
    fi
    if [[ ! -f "${TEMPLATE_PATH}" ]]; then
        log_error "Template not found: ${TEMPLATE_PATH}"
        exit 1
    fi
    if [[ -d "${LEGACY_GIT_DIR}" && ! -d "${GIT_DIR}" ]]; then
        log_error "A legacy plans repository exists at ${LEGACY_GIT_DIR}."
        log_error "Run migrate_legacy_plans_repo.sh instead of initializing a second repository."
        exit 1
    fi

    if [[ -d "${GIT_DIR}" ]]; then
        if git -C "${LOCAL_DIR}" rev-parse -q --verify HEAD >/dev/null 2>&1; then
            log_info "Local repository already initialized at ${GIT_DIR}; no action needed."
            exit 0
        fi
        log_info "Local repository exists without a commit; resuming setup."
    fi

    local outer_name outer_email global_name global_email
    outer_name="$(git -C "${SCOPE_DIR}" config user.name 2>/dev/null || true)"
    outer_email="$(git -C "${SCOPE_DIR}" config user.email 2>/dev/null || true)"
    global_name="$(git config --global user.name 2>/dev/null || true)"
    global_email="$(git config --global user.email 2>/dev/null || true)"
    if [[ -z "${outer_name}" || -z "${outer_email}" ]]; then
        log_error "A usable git user.name and user.email are required before initialization."
        exit 1
    fi

    cp "${TEMPLATE_PATH}" "${GITIGNORE_PATH}"
    git -C "${LOCAL_DIR}" init

    if [[ -z "${global_name}" || -z "${global_email}" ]]; then
        git -C "${LOCAL_DIR}" config user.name "${outer_name}"
        git -C "${LOCAL_DIR}" config user.email "${outer_email}"
    fi

    git -C "${LOCAL_DIR}" add .gitignore
    git -C "${LOCAL_DIR}" commit -m "Initial commit: local developer repository"

    log_info "Local repository initialized successfully at ${GIT_DIR}."
    log_info "Use it for personal context, experimental skills, plans, and other local state."
}

main "$@"
