#!/usr/bin/env bash

set -euo pipefail

SOURCE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
TOOL="${SOURCE_ROOT}/.agents/skills/setup-agentic-scope/scripts/scope_tool.rb"
TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/scope-tool-tests.XXXXXX")"

trap 'rm -rf "${TEST_ROOT}"' EXIT

fail() {
  echo "[FAIL] $1" >&2
  exit 1
}

pass() {
  echo "[PASS] $1"
}

write_file() {
  mkdir -p "$(dirname "$1")"
  printf '%s' "$2" > "$1"
}

fixture="${TEST_ROOT}/company"

help_output="$(ruby "${TOOL}" --help)"
grep -Fq 'setup' <<<"${help_output}" || fail "global help omitted setup command"
grep -Fq 'inspect' <<<"${help_output}" || fail "global help omitted inspect command"
grep -Fq 'adapters' <<<"${help_output}" || fail "global help omitted adapters command"
grep -Fq 'resolve' <<<"${help_output}" || fail "global help omitted resolve command"
pass "global command help"

ruby "${TOOL}" setup \
  --scope-dir "${fixture}" \
  --name atlas-company \
  --description "Company scope for Atlas." \
  --type company \
  --with-local >/dev/null

ruby "${TOOL}" setup \
  --scope-dir "${fixture}/clients/aster" \
  --name aster-client \
  --description "Client scope for Aster." \
  --type client \
  --parent "${fixture}/AGENTS.md" >/dev/null

ruby "${TOOL}" validate --scope "${fixture}/AGENTS.md" >/dev/null
ruby "${TOOL}" validate --scope "${fixture}/clients/aster/AGENTS.md" >/dev/null
grep -Fq -- '- clients/aster/AGENTS.md' "${fixture}/AGENTS.md" || fail "parent did not register direct child"
grep -Fq 'parent: "../../AGENTS.md"' "${fixture}/clients/aster/AGENTS.md" || fail "child did not store scope-relative parent"
[[ -f "${fixture}/.agents/local/README.md" ]] || fail "optional local README was not created"
[[ -f "${fixture}/.agents/local/context/.gitkeep" ]] || fail "optional local scaffold was incomplete"
pass "scope setup, reciprocal registration, and optional local state"

context_file="${fixture}/clients/aster/.agents/context/client.md"
skill_file="${fixture}/clients/aster/.agents/skills/review/SKILL.md"
write_file "${context_file}" $'---\nname: aster-context\ndescription: Context selected only for Aster work.\n---\nBODY_SENTINEL_MUST_NOT_APPEAR\n'
write_file "${skill_file}" $'---\nname: aster-review\ndescription: Review an Aster delivery.\n---\nSKILL_BODY_SENTINEL_MUST_NOT_APPEAR\n'

ruby "${TOOL}" setup \
  --scope-dir "${fixture}/clients/aster" \
  --context "${context_file}" \
  --skill "${skill_file}" >/dev/null

inspection="$(cd "${fixture}/clients/aster" && ruby "${TOOL}" inspect --scope AGENTS.md --include resources,chain --format json)"
grep -Fq '"name": "aster-context"' <<<"${inspection}" || fail "registered context metadata was not inspected"
grep -Fq '"name": "aster-review"' <<<"${inspection}" || fail "registered skill metadata was not inspected"
grep -Fq '"body_loaded": false' <<<"${inspection}" || fail "inspection did not declare header-only behavior"
if grep -Fq 'BODY_SENTINEL' <<<"${inspection}"; then
  fail "inspection returned a context body"
fi
grep -Fq '"declared_by"' <<<"${inspection}" || fail "inspection lost declaring-scope provenance"
pass "registered metadata inspection without body disclosure"

ruby "${TOOL}" setup \
  --scope-dir "${fixture}/clients/beacon" \
  --name beacon-client \
  --description "Unregistered Beacon candidate." \
  --type client >/dev/null

candidates="$(ruby "${TOOL}" candidates --scope "${fixture}/AGENTS.md" --under clients --format json)"
grep -Fq '"name": "aster-client"' <<<"${candidates}" || fail "registered candidate was not reported"
grep -Fq '"registered": true' <<<"${candidates}" || fail "registered candidate status was incorrect"
grep -Fq '"name": "beacon-client"' <<<"${candidates}" || fail "unregistered candidate was not reported"
grep -Fq '"registered": false' <<<"${candidates}" || fail "unregistered candidate was modified or misreported"
pass "explicit-container candidate detection without registration"

boundary_scope="${TEST_ROOT}/isolated/project"
boundary_output="$(ruby "${TOOL}" setup \
  --scope-dir "${boundary_scope}" \
  --name isolated-project \
  --description "Project with an unavailable parent." \
  --type project \
  --parent "${TEST_ROOT}/unavailable/AGENTS.md")"
grep -Fq '"kind": "boundary"' <<<"${boundary_output}" || fail "missing parent was not reported as a boundary"
boundary_validation="$(ruby "${TOOL}" validate --scope "${boundary_scope}/AGENTS.md")"
grep -Fq '"valid": true' <<<"${boundary_validation}" || fail "missing ancestor incorrectly invalidated accessible scope"
grep -Fq 'Parent boundary is missing or inaccessible' <<<"${boundary_validation}" || fail "boundary validation warning was absent"
pass "missing-ancestor boundary behavior"

malformed_parent="${TEST_ROOT}/malformed/AGENTS.md"
write_file "${malformed_parent}" $'# No frontmatter\n'
if ruby "${TOOL}" setup \
  --scope-dir "${TEST_ROOT}/must-not-exist" \
  --name rejected-child \
  --description "Child whose parent is malformed." \
  --type project \
  --parent "${malformed_parent}" >/dev/null 2>&1; then
  fail "malformed accessible parent was accepted"
fi
[[ ! -e "${TEST_ROOT}/must-not-exist/AGENTS.md" ]] || fail "failed preflight partially created child map"
pass "preflight refusal without partial map mutation"

dry_run_scope="${TEST_ROOT}/dry-run"
dry_run_output="$(ruby "${TOOL}" setup \
  --scope-dir "${dry_run_scope}" \
  --name dry-run \
  --description "Dry-run scope." \
  --type project \
  --with-local \
  --dry-run)"
[[ ! -e "${dry_run_scope}/AGENTS.md" ]] || fail "dry run wrote a scope map"
grep -Fq '.agents/local/README.md' <<<"${dry_run_output}" || fail "dry run omitted planned local scaffold changes"
pass "dry-run preflight"

nested_fixture="${TEST_ROOT}/nested/company"
mkdir -p "${nested_fixture}/clients/nested-client"
git -C "${nested_fixture}" init -q
git -C "${nested_fixture}/clients/nested-client" init -q
ruby "${TOOL}" setup \
  --scope-dir "${nested_fixture}" \
  --name nested-company \
  --description "Company scope in an outer repository." \
  --type company >/dev/null
ruby "${TOOL}" setup \
  --scope-dir "${nested_fixture}/clients/nested-client" \
  --name nested-client \
  --description "Client scope in a nested repository." \
  --type client \
  --parent "${nested_fixture}/AGENTS.md" >/dev/null
ruby "${TOOL}" validate --scope "${nested_fixture}/clients/nested-client/AGENTS.md" >/dev/null
[[ -d "${nested_fixture}/.git" ]] || fail "outer repository fixture was lost"
[[ -d "${nested_fixture}/clients/nested-client/.git" ]] || fail "nested repository fixture was lost"
pass "context registration across nested repository boundaries"

replacement_parent="${fixture}/departments/replacement"
ruby "${TOOL}" setup \
  --scope-dir "${replacement_parent}" \
  --name replacement-parent \
  --description "Replacement parent used to verify reparenting." \
  --type department >/dev/null
ruby "${TOOL}" setup \
  --scope-dir "${fixture}/clients/aster" \
  --parent "${replacement_parent}/AGENTS.md" >/dev/null
if grep -Fq -- '- clients/aster/AGENTS.md' "${fixture}/AGENTS.md"; then
  fail "reparenting left a stale entry in the old parent"
fi
grep -Fq '../../clients/aster/AGENTS.md' "${replacement_parent}/AGENTS.md" || fail "reparenting did not register the new parent"
ruby "${TOOL}" validate --scope "${fixture}/clients/aster/AGENTS.md" >/dev/null
pass "transactional reparenting and old-parent repair"

parent_skill="${replacement_parent}/.agents/skills/review/SKILL.md"
write_file "${parent_skill}" $'---\nname: aster-review\ndescription: Deliberate duplicate for validation.\n---\n'
ruby "${TOOL}" setup --scope-dir "${replacement_parent}" --skill "${parent_skill}" >/dev/null
if ruby "${TOOL}" validate --scope "${fixture}/clients/aster/AGENTS.md" >/dev/null 2>&1; then
  fail "duplicate effective skill name was accepted"
fi
duplicate_output="$(ruby "${TOOL}" validate --scope "${fixture}/clients/aster/AGENTS.md" 2>/dev/null || true)"
grep -Fq "Duplicate effective skill name 'aster-review'" <<<"${duplicate_output}" || fail "duplicate skill diagnostic was not specific"
pass "duplicate effective skill detection"

adapter_fixture="${TEST_ROOT}/adapters"
git -C "${TEST_ROOT}" init -q adapters
ruby "${TOOL}" setup \
  --scope-dir "${adapter_fixture}" \
  --name adapter-root \
  --description "Root used to verify platform adapters." \
  --type company >/dev/null
write_file "${adapter_fixture}/.agents/skills/root-skill/SKILL.md" $'---\nname: root-skill\ndescription: Root adapter fixture skill.\n---\nROOT_SKILL_BODY\n'
ruby "${TOOL}" setup \
  --scope-dir "${adapter_fixture}" \
  --skill "${adapter_fixture}/.agents/skills/root-skill/SKILL.md" >/dev/null
ruby "${TOOL}" setup \
  --scope-dir "${adapter_fixture}/clients/aster" \
  --name adapter-child \
  --description "Child used to verify path-specific adapters." \
  --type client \
  --parent "${adapter_fixture}/AGENTS.md" >/dev/null
mkdir -p "${adapter_fixture}/clients/aster/.agents/skills"

root_adapter_output="$(ruby "${TOOL}" adapters --scope "${adapter_fixture}/AGENTS.md")"
child_adapter_output="$(ruby "${TOOL}" adapters --scope "${adapter_fixture}/clients/aster/AGENTS.md")"
[[ -f "${adapter_fixture}/CLAUDE.md" ]] || fail "root Claude adapter was not generated"
[[ "$(readlink "${adapter_fixture}/.claude/skills")" == '../.agents/skills' ]] || fail "root Claude skill link is incorrect"
[[ -f "${adapter_fixture}/.cursor/rules/agentic-scope.mdc" ]] || fail "root Cursor adapter was not generated"
[[ -f "${adapter_fixture}/.github/copilot-instructions.md" ]] || fail "root Copilot adapter was not generated"
[[ -f "${adapter_fixture}/.github/instructions/clients--aster.instructions.md" ]] || fail "nested Copilot adapter was not generated at repository root"
[[ "$(readlink "${adapter_fixture}/clients/aster/.claude/skills")" == '../.agents/skills' ]] || fail "child Claude skill link is incorrect"
grep -Fq '"platform": "codex"' <<<"${root_adapter_output}" || fail "Codex native strategy was not reported"
grep -Fq 'clients/aster/**/*' "${adapter_fixture}/.github/instructions/clients--aster.instructions.md" || fail "nested Copilot applyTo scope is incorrect"
if rg -Fq 'ROOT_SKILL_BODY' "${adapter_fixture}/CLAUDE.md" "${adapter_fixture}/.cursor/rules/agentic-scope.mdc" "${adapter_fixture}/.github"; then
  fail "an adapter duplicated a canonical skill body"
fi
second_adapter_output="$(ruby "${TOOL}" adapters --scope "${adapter_fixture}/clients/aster/AGENTS.md")"
grep -Fq '"changes": [' <<<"${second_adapter_output}" || fail "idempotent adapter result omitted changes"
grep -Fq '"valid": true' <<<"$(ruby "${TOOL}" adapters --scope "${adapter_fixture}/clients/aster/AGENTS.md" --check)" || fail "generated adapters did not pass check mode"
ln -sfn '../wrong-skills' "${adapter_fixture}/clients/aster/.claude/skills"
if ruby "${TOOL}" adapters --scope "${adapter_fixture}/clients/aster/AGENTS.md" --check >/dev/null 2>&1; then
  fail "stale Claude skill link passed adapter check"
fi
ruby "${TOOL}" adapters --scope "${adapter_fixture}/clients/aster/AGENTS.md" >/dev/null
[[ "$(readlink "${adapter_fixture}/clients/aster/.claude/skills")" == '../.agents/skills' ]] || fail "stale Claude skill link was not repaired"
pass "idempotent, repairable, source-of-truth platform adapters"

collision_fixture="${TEST_ROOT}/adapter-collision"
ruby "${TOOL}" setup \
  --scope-dir "${collision_fixture}" \
  --name adapter-collision \
  --description "Scope with an unmanaged platform file." \
  --type project >/dev/null
write_file "${collision_fixture}/CLAUDE.md" $'# User-owned Claude instructions\n'
if ruby "${TOOL}" adapters --scope "${collision_fixture}/AGENTS.md" --platforms claude >/dev/null 2>&1; then
  fail "unmanaged Claude adapter was overwritten"
fi
grep -Fq 'User-owned Claude instructions' "${collision_fixture}/CLAUDE.md" || fail "unmanaged Claude adapter content changed"
pass "unmanaged adapter collision protection"

ruby "${TOOL}" setup --scope-dir "${adapter_fixture}" --with-local >/dev/null
inherited_resolution="$(ruby "${TOOL}" resolve --start "${adapter_fixture}/clients/aster" --format json)"
grep -Fq '"selection_reason": "only_applicable"' <<<"${inherited_resolution}" || fail "single ancestor local directory was not selected"
ruby "${TOOL}" setup --scope-dir "${adapter_fixture}/clients/aster" --with-local >/dev/null
active_resolution="$(ruby "${TOOL}" resolve --start "${adapter_fixture}/clients/aster" --format json)"
grep -Fq '"selection_reason": "active_scope"' <<<"${active_resolution}" || fail "active-scope local directory was not preferred"
ruby "${TOOL}" setup \
  --scope-dir "${adapter_fixture}/clients/aster/projects/orbit" \
  --name orbit-project \
  --description "Leaf used to verify ambiguous local resolution." \
  --type project \
  --parent "${adapter_fixture}/clients/aster/AGENTS.md" >/dev/null
if ruby "${TOOL}" resolve --start "${adapter_fixture}/clients/aster/projects/orbit" >/dev/null 2>&1; then
  fail "multiple ancestor local directories were selected silently"
fi
explicit_resolution="$(ruby "${TOOL}" resolve \
  --start "${adapter_fixture}/clients/aster/projects/orbit" \
  --local "${adapter_fixture}/.agents/local" \
  --format json)"
grep -Fq '"selection_reason": "explicit"' <<<"${explicit_resolution}" || fail "explicit local-directory selection failed"
pass "deterministic active-scope and local-directory resolution"

ruby "${TOOL}" setup \
  --scope-dir "${adapter_fixture}/clients/beacon" \
  --name adapter-beacon \
  --description "Sibling used to verify isolation validation." \
  --type client \
  --parent "${adapter_fixture}/AGENTS.md" >/dev/null
ruby "${TOOL}" setup --scope-dir "${adapter_fixture}/clients/aster" --confidential >/dev/null
ruby "${TOOL}" setup --scope-dir "${adapter_fixture}/clients/beacon" --confidential >/dev/null
beacon_context="${adapter_fixture}/clients/beacon/.agents/context/private.md"
write_file "${beacon_context}" $'---\nname: beacon-private\ndescription: Context that belongs only to Beacon.\n---\nPRIVATE_BODY\n'
ruby "${TOOL}" setup \
  --scope-dir "${adapter_fixture}/clients/aster" \
  --context "${beacon_context}" >/dev/null
if ruby "${TOOL}" validate --scope "${adapter_fixture}/AGENTS.md" --descendants >/dev/null 2>&1; then
  fail "cross-sibling resource reference passed descendant validation"
fi
tree_validation="$(ruby "${TOOL}" validate --scope "${adapter_fixture}/AGENTS.md" --descendants 2>/dev/null || true)"
grep -Fq 'Cross-sibling context reference' <<<"${tree_validation}" || fail "cross-sibling diagnostic was not specific"
grep -Fq 'Confidential sibling scopes share readable repository' <<<"${tree_validation}" || fail "confidential sibling co-location warning was absent"
pass "registered-tree validation and sibling-reference isolation"

echo "Completed 14 scope-management and adapter regression checks."
