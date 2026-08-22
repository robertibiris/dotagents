#!/usr/bin/env bash

set -euo pipefail

experiment_root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
explicit_root="$experiment_root/alternative-a-explicit/atlas-collective"
native_root="$experiment_root/alternative-b-native/borealis-group"
hybrid_root="$experiment_root/alternative-c-hybrid/northstar-holdings"
repo_root="$(cd "$experiment_root/../.." && pwd)"
scope_tool="$repo_root/.agents/skills/setup-agentic-scope/scripts/scope_tool.rb"
test_root="$(mktemp -d "${TMPDIR:-/tmp}/hybrid-agentic-fixture.XXXXXX")"

trap 'rm -rf "$test_root"' EXIT

require_file() {
  if [[ ! -f "$1" ]]; then
    echo "Missing file: $1" >&2
    exit 1
  fi
}

require_text() {
  if ! grep -Fq "$2" "$1"; then
    echo "Missing text '$2' in $1" >&2
    exit 1
  fi
}

for marker_file in \
  "$explicit_root/.agents/context/company.md:ATLAS-COMPANY-CONTEXT" \
  "$explicit_root/clients/aster-labs/.agents/context/client.md:ASTER-CLIENT-CONTEXT" \
  "$explicit_root/clients/aster-labs/projects/orbit-console/.agents/context/project.md:ORBIT-PROJECT-CONTEXT" \
  "$explicit_root/clients/ember-works/.agents/context/client.md:EMBER-CLIENT-CONTEXT" \
  "$native_root/.agents/context/company.md:BOREALIS-COMPANY-CONTEXT" \
  "$native_root/clients/cedar-health/.agents/context/client.md:CEDAR-CLIENT-CONTEXT" \
  "$native_root/clients/cedar-health/projects/pulse-portal/.agents/context/project.md:PULSE-PROJECT-CONTEXT" \
  "$native_root/clients/harbor-studio/.agents/context/client.md:HARBOR-CLIENT-CONTEXT"
do
  file="${marker_file%%:*}"
  marker="${marker_file##*:}"
  require_file "$file"
  require_text "$file" "$marker"
done

# Alternative C: correctness through registered maps, before any platform adapter exists.
ruby "$scope_tool" validate --scope "$hybrid_root/AGENTS.md" --descendants >/dev/null

hybrid_leaf="$hybrid_root/clients/aurora-analytics/projects/lumen-migration"
chain_output="$(ruby "$scope_tool" inspect --scope "$hybrid_leaf/AGENTS.md" --include chain,resources --format json)"
for expected in northstar-holdings aurora-analytics lumen-migration lumen-project-context lumen-release; do
  grep -Fq "\"name\": \"$expected\"" <<<"$chain_output" || {
    echo "Alternative C chain omitted $expected" >&2
    exit 1
  }
done
if grep -Fq 'BODY-SENTINEL' <<<"$chain_output"; then
  echo "Alternative C metadata inspection leaked a resource body" >&2
  exit 1
fi
require_text <(printf '%s' "$chain_output") '"body_loaded": false'
require_text <(printf '%s' "$chain_output") '"declared_by"'
require_text <(printf '%s' "$chain_output") '"resolved_path"'
if grep -Fq 'solstice' <<<"$chain_output"; then
  echo "Alternative C leaf chain leaked its sibling scope" >&2
  exit 1
fi

children_output="$(ruby "$scope_tool" inspect --scope "$hybrid_root/AGENTS.md" --include children --format json)"
grep -Fq '"name": "aurora-analytics"' <<<"$children_output" || { echo "Alternative C omitted Aurora direct-child metadata" >&2; exit 1; }
grep -Fq '"name": "solstice-media"' <<<"$children_output" || { echo "Alternative C omitted Solstice direct-child metadata" >&2; exit 1; }
if grep -Fq 'BODY-SENTINEL' <<<"$children_output"; then
  echo "Alternative C direct-child routing eagerly loaded child resources" >&2
  exit 1
fi

# A partial Aurora subtree stays usable and reports the inaccessible company boundary.
mkdir -p "$test_root/reduced/clients"
cp -R "$hybrid_root/clients/aurora-analytics" "$test_root/reduced/clients/aurora-analytics"
reduced_output="$(ruby "$scope_tool" validate --scope "$test_root/reduced/clients/aurora-analytics/AGENTS.md" --format json)"
grep -Fq '"valid": true' <<<"$reduced_output" || { echo "Alternative C reduced subtree became invalid" >&2; exit 1; }
grep -Fq 'Parent boundary is missing or inaccessible' <<<"$reduced_output" || { echo "Alternative C reduced subtree omitted its boundary warning" >&2; exit 1; }

# Repository topology is independent: the client may be a nested repository.
cp -R "$hybrid_root" "$test_root/nested-repositories"
git -C "$test_root/nested-repositories" init -q
git -C "$test_root/nested-repositories/clients/aurora-analytics" init -q
ruby "$scope_tool" validate \
  --scope "$test_root/nested-repositories/clients/aurora-analytics/projects/lumen-migration/AGENTS.md" >/dev/null

# Thin adapters improve ergonomics but do not carry canonical context bodies.
cp -R "$hybrid_root" "$test_root/adapters"
git -C "$test_root/adapters" init -q
for scope in \
  "$test_root/adapters" \
  "$test_root/adapters/clients/aurora-analytics" \
  "$test_root/adapters/clients/aurora-analytics/projects/lumen-migration" \
  "$test_root/adapters/clients/solstice-media"
do
  ruby "$scope_tool" adapters --scope "$scope/AGENTS.md" >/dev/null
  ruby "$scope_tool" adapters --scope "$scope/AGENTS.md" --check >/dev/null
done
for adapter in \
  "$test_root/adapters/CLAUDE.md" \
  "$test_root/adapters/.cursor/rules/agentic-scope.mdc" \
  "$test_root/adapters/.github/copilot-instructions.md" \
  "$test_root/adapters/.github/instructions/clients--aurora-analytics.instructions.md"
do
  require_file "$adapter"
  if grep -Fq 'BODY-SENTINEL' "$adapter"; then
    echo "Alternative C adapter copied a canonical body: $adapter" >&2
    exit 1
  fi
done

require_text "$explicit_root/clients/aster-labs/AGENTS.md" 'Parent: `../../AGENTS.md`'
require_text "$explicit_root/clients/aster-labs/projects/orbit-console/AGENTS.md" 'Parent: `../../AGENTS.md`'

for skill_file in \
  "$explicit_root/.agents/catalog/skills/atlas-governance/SKILL.md" \
  "$explicit_root/clients/aster-labs/.agents/catalog/skills/aster-engagement-review/SKILL.md" \
  "$explicit_root/clients/aster-labs/projects/orbit-console/.agents/catalog/skills/orbit-release-check/SKILL.md" \
  "$explicit_root/clients/ember-works/.agents/catalog/skills/ember-portfolio-review/SKILL.md"
do
  require_file "$skill_file"
done

for scope in \
  "$native_root" \
  "$native_root/clients/cedar-health" \
  "$native_root/clients/cedar-health/projects/pulse-portal" \
  "$native_root/clients/harbor-studio"
do
  if [[ ! -L "$scope/.claude/skills" ]]; then
    echo "Missing Claude skill link: $scope/.claude/skills" >&2
    exit 1
  fi
  if [[ ! -d "$scope/.claude/skills" ]]; then
    echo "Broken Claude skill link: $scope/.claude/skills" >&2
    exit 1
  fi
done

echo "Hierarchical agentic infrastructure Alternatives A, B, and C are structurally valid."
