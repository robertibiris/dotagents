#!/usr/bin/env bash

set -euo pipefail

experiment_root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
explicit_root="$experiment_root/alternative-a-explicit/atlas-collective"
native_root="$experiment_root/alternative-b-native/borealis-group"

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

echo "Hierarchical agentic infrastructure fixtures are structurally valid."
