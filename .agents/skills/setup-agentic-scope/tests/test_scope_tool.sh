#!/usr/bin/env bash

set -euo pipefail

SOURCE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
TOOL="${SOURCE_ROOT}/.agents/skills/setup-agentic-scope/scripts/scope_tool.rb"
TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/scope-tool-tests.XXXXXX")"

trap 'rm -rf "${TEST_ROOT}"' EXIT

fail() { echo "[FAIL] $1" >&2; exit 1; }
pass() { echo "[PASS] $1"; }
write_file() { mkdir -p "$(dirname "$1")"; printf '%s' "$2" > "$1"; }

help_output="$(ruby "${TOOL}" --help)"
for command in setup register-child resolve inspect candidates adapters validate; do
  grep -Fq "${command}" <<<"${help_output}" || fail "global help omitted ${command}"
done
pass "global command help"

fixture="${TEST_ROOT}/workspace"
root="${fixture}/AGENTS.md"
child="${fixture}/initiatives/atlas/AGENTS.md"
leaf="${fixture}/initiatives/atlas/services/orbit/AGENTS.md"

ruby "${TOOL}" setup --scope-dir "${fixture}" --name shared-workspace \
  --description "Shared entry scope for independent initiatives." --type workspace --with-local >/dev/null
ruby "${TOOL}" setup --scope-dir "$(dirname "${child}")" --name atlas-initiative \
  --description "Independent Atlas initiative." --type initiative >/dev/null
[[ -f "${fixture}/.agents/local/README.md" ]] || fail "optional local README was not created"
[[ -f "${fixture}/.agents/local/plans/.gitkeep" ]] || fail "optional local scaffold was incomplete"
grep -Fq 'type: workspace' "${root}" || fail "optional type was not written"
if grep -Fq 'parent:' "${child}"; then fail "standalone child contains a parent dependency"; fi
pass "independent lean scope setup and optional local state"

child_before="$(shasum -a 256 "${child}" | cut -d' ' -f1)"
ruby "${TOOL}" register-child --scope "${root}" --child "${child}" \
  --when "Use for the Atlas initiative and its services." >/dev/null
grep -Fq 'path: initiatives/atlas/AGENTS.md' "${root}" || fail "parent did not register child path"
grep -Fq 'when: Use for the Atlas initiative and its services.' "${root}" || fail "parent did not store routing hint"
[[ "${child_before}" == "$(shasum -a 256 "${child}" | cut -d' ' -f1)" ]] || fail "registration mutated the child"
ruby "${TOOL}" register-child --scope "${root}" --child "${child}" --when "Use for Atlas delivery work." >/dev/null
[[ "$(rg -c 'path: initiatives/atlas/AGENTS.md' "${root}")" == 1 ]] || fail "registration duplicated a child"
grep -Fq 'when: Use for Atlas delivery work.' "${root}" || fail "registration did not update the hint"
pass "one-way child registration and idempotent hint update"

second_parent="${TEST_ROOT}/portfolio/AGENTS.md"
ruby "${TOOL}" setup --scope-dir "$(dirname "${second_parent}")" --name delivery-portfolio \
  --description "A second independent composition root." >/dev/null
ruby "${TOOL}" register-child --scope "${second_parent}" --child "${child}" \
  --when "Use for Atlas portfolio reporting." >/dev/null
ruby "${TOOL}" validate --scope "${root}" --descendants >/dev/null
ruby "${TOOL}" validate --scope "${second_parent}" --descendants >/dev/null
pass "one child registered by multiple independent parents"

context_file="$(dirname "${child}")/.agents/context/initiative.md"
skill_file="$(dirname "${child}")/.agents/skills/review/SKILL.md"
write_file "${context_file}" $'---\nname: atlas-context\ndescription: Context for Atlas decisions.\n---\nBODY_SENTINEL_MUST_NOT_APPEAR\n'
write_file "${skill_file}" $'---\nname: atlas-review\ndescription: Review an Atlas delivery.\n---\nSKILL_BODY_SENTINEL_MUST_NOT_APPEAR\n'
ruby "${TOOL}" setup --scope-dir "$(dirname "${child}")" --context "${context_file}" --skill "${skill_file}" >/dev/null
inspection="$(ruby "${TOOL}" inspect --scope "${child}" --include map,resources --format json)"
grep -Fq '"name": "atlas-context"' <<<"${inspection}" || fail "registered context metadata was not inspected"
grep -Fq '"name": "atlas-review"' <<<"${inspection}" || fail "registered skill metadata was not inspected"
grep -Fq '"body_loaded": false' <<<"${inspection}" || fail "inspection did not declare header-only behavior"
if grep -Fq 'BODY_SENTINEL' <<<"${inspection}"; then fail "inspection disclosed a resource body"; fi
children_inspection="$(ruby "${TOOL}" inspect --scope "${root}" --include children --format json)"
grep -Fq '"routing_hint": "Use for Atlas delivery work."' <<<"${children_inspection}" || fail "child inspection omitted hint"
grep -Fq '"description": "Independent Atlas initiative."' <<<"${children_inspection}" || fail "child description was not verified"
pass "metadata-first resource and child inspection"

ruby "${TOOL}" setup --scope-dir "${fixture}/initiatives/beacon" --name beacon-initiative \
  --description "Unregistered Beacon candidate." >/dev/null
candidates="$(ruby "${TOOL}" candidates --scope "${root}" --under initiatives --format json)"
grep -Fq '"name": "atlas-initiative"' <<<"${candidates}" || fail "registered candidate was not reported"
grep -Fq '"routing_hint": "Use for Atlas delivery work."' <<<"${candidates}" || fail "candidate omitted hint"
grep -Fq '"name": "beacon-initiative"' <<<"${candidates}" || fail "unregistered candidate was not reported"
grep -Fq '"registered": false' <<<"${candidates}" || fail "unregistered candidate status was wrong"
pass "explicit-container candidate detection"

ruby "${TOOL}" register-child --scope "${root}" --child "${fixture}/initiatives/beacon" \
  --when "Use for Atlas delivery work." >/dev/null
ambiguous_output="$(ruby "${TOOL}" validate --scope "${root}" --format text)"
grep -Fq 'ambiguous requests require clarification' <<<"${ambiguous_output}" || fail "identical sibling hints produced no ambiguity warning"
ruby "${TOOL}" register-child --scope "${root}" --child "${fixture}/initiatives/beacon" \
  --when "Use for Beacon delivery work." >/dev/null
pass "deterministic warning for identical routing hints"

ruby "${TOOL}" setup --scope-dir "$(dirname "${leaf}")" --name orbit-service \
  --description "Standalone Orbit service." >/dev/null
ruby "${TOOL}" register-child --scope "${child}" --child "${leaf}" --when "Use for the Orbit service runtime." >/dev/null
standalone_resolution="$(ruby "${TOOL}" resolve --start "$(dirname "${leaf}")" --format json)"
grep -Fq '"name": "orbit-service"' <<<"${standalone_resolution}" || fail "standalone leaf did not resolve itself"
grep -Fq '"entry_scope"' <<<"${standalone_resolution}" || fail "standalone resolution omitted entry"
composed_resolution="$(ruby "${TOOL}" resolve --entry "${root}" --start "$(dirname "${leaf}")" --format json)"
for name in shared-workspace atlas-initiative orbit-service; do
  grep -Fq "\"name\": \"${name}\"" <<<"${composed_resolution}" || fail "composed route omitted ${name}"
done
grep -Fq '"selected_local": null' <<<"${composed_resolution}" || fail "parent local was selected implicitly"
explicit_local="$(ruby "${TOOL}" resolve --entry "${root}" --start "$(dirname "${leaf}")" \
  --local "${fixture}/.agents/local" --format json)"
grep -Fq '"selection_reason": "explicit"' <<<"${explicit_local}" || fail "explicit route-local selection failed"
if ruby "${TOOL}" resolve --entry "${root}" --start "${TEST_ROOT}/portfolio" >/dev/null 2>&1; then
  fail "entry resolved a target outside its composed tree"
fi
pass "standalone and composed-route resolution with explicit local ownership"

dry_run_scope="${TEST_ROOT}/dry-run"
dry_run_output="$(ruby "${TOOL}" setup --scope-dir "${dry_run_scope}" --name dry-run \
  --description "Dry-run scope." --with-local --dry-run)"
[[ ! -e "${dry_run_scope}/AGENTS.md" ]] || fail "dry run wrote a scope map"
grep -Fq '.agents/local/README.md' <<<"${dry_run_output}" || fail "dry run omitted local scaffold changes"
legacy="${TEST_ROOT}/legacy/AGENTS.md"
write_file "${legacy}" $'---\nname: legacy\ndescription: Legacy bidirectional scope.\nscope:\n  parent: null\n  children: []\n---\n'
if ruby "${TOOL}" validate --scope "${legacy}" >/dev/null 2>&1; then fail "legacy schema was accepted"; fi
bad_hint="${TEST_ROOT}/bad-hint/AGENTS.md"
write_file "${bad_hint}" $'---\nname: bad-hint\ndescription: Invalid child registration.\nchildren:\n  - path: child/AGENTS.md\n---\n'
if ruby "${TOOL}" validate --scope "${bad_hint}" >/dev/null 2>&1; then fail "missing routing hint was accepted"; fi
bad_resource="${TEST_ROOT}/bad-resource/AGENTS.md"
write_file "${bad_resource}" $'---\nname: bad-resource\ndescription: Invalid resource registration.\nresources:\n  context:\n    - 42\n---\n'
if ruby "${TOOL}" validate --scope "${bad_resource}" >/dev/null 2>&1; then fail "non-string resource path was accepted"; fi
pass "dry-run behavior and strict schema migration gate"

nested="${TEST_ROOT}/nested-root"
mkdir -p "${nested}/package"
git -C "${nested}" init -q
git -C "${nested}/package" init -q
ruby "${TOOL}" setup --scope-dir "${nested}" --name nested-root --description "Outer repository scope." >/dev/null
ruby "${TOOL}" setup --scope-dir "${nested}/package" --name nested-package \
  --description "Independent nested repository scope." >/dev/null
ruby "${TOOL}" register-child --scope "${nested}" --child "${nested}/package" --when "Use for the nested package." >/dev/null
ruby "${TOOL}" validate --scope "${nested}" --descendants >/dev/null
[[ -d "${nested}/.git" && -d "${nested}/package/.git" ]] || fail "nested repository fixture was damaged"
pass "composition across nested repository boundaries"

duplicate_skill="${fixture}/.agents/skills/duplicate/SKILL.md"
write_file "${duplicate_skill}" $'---\nname: atlas-review\ndescription: Deliberate route duplicate.\n---\n'
ruby "${TOOL}" setup --scope-dir "${fixture}" --skill "${duplicate_skill}" >/dev/null
if ruby "${TOOL}" validate --scope "${root}" --descendants >/dev/null 2>&1; then fail "duplicate route skill was accepted"; fi
duplicate_output="$(ruby "${TOOL}" validate --scope "${root}" --descendants 2>/dev/null || true)"
grep -Fq "Duplicate effective skill name 'atlas-review'" <<<"${duplicate_output}" || fail "duplicate diagnostic was vague"
pass "duplicate skill detection along composed routes"

cycle_root="${TEST_ROOT}/cycle/root"
cycle_child="${cycle_root}/child"
ruby "${TOOL}" setup --scope-dir "${cycle_root}" --name cycle-root --description "Cycle test root." >/dev/null
ruby "${TOOL}" setup --scope-dir "${cycle_child}" --name cycle-child --description "Cycle test child." >/dev/null
ruby "${TOOL}" register-child --scope "${cycle_root}" --child "${cycle_child}" --when "Use for cycle child work." >/dev/null
ruby "${TOOL}" register-child --scope "${cycle_child}" --child "${cycle_root}" --when "Deliberate invalid cycle." >/dev/null
if ruby "${TOOL}" validate --scope "${cycle_root}" --descendants >/dev/null 2>&1; then fail "child-registration cycle was accepted"; fi
cycle_output="$(ruby "${TOOL}" validate --scope "${cycle_root}" --descendants 2>/dev/null || true)"
grep -Fq 'Child-registration cycle detected' <<<"${cycle_output}" || fail "cycle diagnostic was vague"
pass "child-registration cycle detection"

# Use a clean tree for sibling-isolation validation.
isolation="${TEST_ROOT}/isolation"
git -C "${TEST_ROOT}" init -q isolation
ruby "${TOOL}" setup --scope-dir "${isolation}" --name isolation-root --description "Sibling isolation root." >/dev/null
for name in amber blue; do
  ruby "${TOOL}" setup --scope-dir "${isolation}/${name}" --name "${name}-scope" \
    --description "${name} independent scope." --confidential >/dev/null
  ruby "${TOOL}" register-child --scope "${isolation}" --child "${isolation}/${name}" \
    --when "Use for ${name} work." >/dev/null
done
blue_context="${isolation}/blue/.agents/context/private.md"
write_file "${blue_context}" $'---\nname: blue-private\ndescription: Blue-only context.\n---\nPRIVATE_BODY\n'
ruby "${TOOL}" setup --scope-dir "${isolation}/amber" --context "${blue_context}" >/dev/null
if ruby "${TOOL}" validate --scope "${isolation}" --descendants >/dev/null 2>&1; then
  fail "cross-sibling reference passed validation"
fi
tree_output="$(ruby "${TOOL}" validate --scope "${isolation}" --descendants 2>/dev/null || true)"
grep -Fq 'Cross-sibling context reference' <<<"${tree_output}" || fail "cross-sibling diagnostic was vague"
grep -Fq 'Confidential sibling scopes share readable repository' <<<"${tree_output}" || fail "co-location warning was absent"
pass "registered-tree sibling isolation diagnostics"

adapter_fixture="${TEST_ROOT}/adapters"
git -C "${TEST_ROOT}" init -q adapters
ruby "${TOOL}" setup --scope-dir "${adapter_fixture}" --name adapter-root --description "Adapter fixture." >/dev/null
write_file "${adapter_fixture}/.agents/skills/root-skill/SKILL.md" $'---\nname: root-skill\ndescription: Root adapter fixture skill.\n---\nROOT_SKILL_BODY\n'
ruby "${TOOL}" setup --scope-dir "${adapter_fixture}" --skill "${adapter_fixture}/.agents/skills/root-skill/SKILL.md" >/dev/null
ruby "${TOOL}" adapters --scope "${adapter_fixture}" >/dev/null
[[ -f "${adapter_fixture}/CLAUDE.md" ]] || fail "Claude adapter was not generated"
[[ "$(readlink "${adapter_fixture}/.claude/skills")" == '../.agents/skills' ]] || fail "Claude skill link is wrong"
[[ -f "${adapter_fixture}/.cursor/rules/agentic-scope.mdc" ]] || fail "Cursor adapter was not generated"
[[ -f "${adapter_fixture}/.github/copilot-instructions.md" ]] || fail "Copilot adapter was not generated"
if rg -Fq 'ROOT_SKILL_BODY' "${adapter_fixture}/CLAUDE.md" "${adapter_fixture}/.cursor" "${adapter_fixture}/.github"; then
  fail "an adapter duplicated canonical skill content"
fi
ruby "${TOOL}" adapters --scope "${adapter_fixture}" --check >/dev/null
ln -sfn '../wrong-skills' "${adapter_fixture}/.claude/skills"
if ruby "${TOOL}" adapters --scope "${adapter_fixture}" --check >/dev/null 2>&1; then fail "stale skill link passed"; fi
ruby "${TOOL}" adapters --scope "${adapter_fixture}" >/dev/null
pass "idempotent and repairable source-of-truth adapters"

collision="${TEST_ROOT}/adapter-collision"
ruby "${TOOL}" setup --scope-dir "${collision}" --name adapter-collision --description "Unmanaged adapter fixture." >/dev/null
write_file "${collision}/CLAUDE.md" $'# User-owned Claude instructions\n'
if ruby "${TOOL}" adapters --scope "${collision}" --platforms claude >/dev/null 2>&1; then
  fail "unmanaged Claude adapter was overwritten"
fi
grep -Fq 'User-owned Claude instructions' "${collision}/CLAUDE.md" || fail "unmanaged adapter content changed"
pass "unmanaged adapter collision protection"

echo "Completed 15 one-way scope-management and adapter regression checks."
