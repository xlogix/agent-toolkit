#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INPUT="$SCRIPT_DIR/../references/tool-list.tsv"
OUTPUT="$SCRIPT_DIR/../references/TOOL-CATALOG.md"
GENERATED_ON="$(date +%F)"

escape_field() {
  printf '%s' "$1" | sed 's/|/\\|/g'
}

{
  cat <<EOF
# Tool Catalog

This file is generated from \`skills/references/tool-list.tsv\`.
Do not edit manually. Regenerate with:
\`bash skills/scripts/generate-tool-catalog.sh\`.

Generated on: $GENERATED_ON

| Tool | Status | SDLC Stage | Primary Use | Pairs Well With | Notes |
|---|---|---|---|---|---|
EOF

  while IFS=$'\t' read -r tool status stage primary_use pairs_with notes; do
    [[ -z "${tool}" || "${tool}" == \#* ]] && continue

    pairs_with="${pairs_with:--}"
    notes="${notes:--}"

    printf "| \`%s\` | %s | %s | %s | %s | %s |\n" \
      "$(escape_field "$tool")" \
      "$(escape_field "$status")" \
      "$(escape_field "$stage")" \
      "$(escape_field "$primary_use")" \
      "$(escape_field "$pairs_with")" \
      "$(escape_field "$notes")"
  done < "$INPUT"
} > "$OUTPUT"

printf 'Generated %s from %s\n' "$OUTPUT" "$INPUT"
