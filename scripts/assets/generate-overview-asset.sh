#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
RESULTS_ROOT="$ROOT_DIR/benchmarks/results"
OUTPUT_SVG="$ROOT_DIR/assets/agenttools-assemble-overview.svg"
OUTPUT_PNG="$ROOT_DIR/assets/agenttools-assemble-overview.png"

usage() {
  cat <<'EOF'
Usage: bash scripts/assets/generate-overview-asset.sh [--results-dir <dir>]

Generates assets/agenttools-assemble-overview.svg from benchmark results.
If ImageMagick is available, also refreshes the PNG fallback.
EOF
}

RESULTS_DIR=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --results-dir)
      shift
      RESULTS_DIR="${1:-}"
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage
      exit 1
      ;;
  esac
  shift
done

if [[ -z "$RESULTS_DIR" ]]; then
  if [[ ! -d "$RESULTS_ROOT" ]]; then
    echo "Error: benchmark results root not found: $RESULTS_ROOT" >&2
    exit 1
  fi
  RESULTS_DIR="$(find "$RESULTS_ROOT" -mindepth 1 -maxdepth 1 -type d | sort | tail -n 1)"
fi

if [[ -z "$RESULTS_DIR" || ! -d "$RESULTS_DIR" ]]; then
  echo "Error: no benchmark results directory found." >&2
  exit 1
fi

RESULTS_TSV="$RESULTS_DIR/results.tsv"
REPORT_MD="$RESULTS_DIR/report.md"

if [[ ! -f "$RESULTS_TSV" ]]; then
  echo "Error: missing results file: $RESULTS_TSV" >&2
  exit 1
fi

if [[ ! -f "$REPORT_MD" ]]; then
  echo "Error: missing report file: $REPORT_MD" >&2
  exit 1
fi

extract_speedup() {
  local case_id="$1"
  local command="$2"
  awk -F'\t' -v c="$case_id" -v n="$command" '
    NR > 1 && $1 == c && $2 == n { print $9; exit }
  ' "$RESULTS_TSV"
}

fmt2() {
  awk -v x="$1" 'BEGIN { printf "%.2f", x }'
}

SEARCH_SPEEDUP="$(extract_speedup "search-recursive" "rg")"
FD_SPEEDUP="$(extract_speedup "file-discovery" "fd")"
PIPELINE_SPEEDUP="$(extract_speedup "find-then-search" "rg-glob")"
AST_SPEEDUP="$(extract_speedup "structural-search" "ast-grep")"
JQ_SPEEDUP="$(extract_speedup "json-query" "jq")"
SD_SPEEDUP="$(extract_speedup "search-replace" "sd")"

if [[ -z "$SEARCH_SPEEDUP" || -z "$FD_SPEEDUP" || -z "$PIPELINE_SPEEDUP" || -z "$AST_SPEEDUP" || -z "$JQ_SPEEDUP" || -z "$SD_SPEEDUP" ]]; then
  echo "Error: failed to extract one or more benchmark metrics." >&2
  exit 1
fi

RUNS_LINE="$(grep -E '^- Runs per command:' "$REPORT_MD" || true)"
WARMUP_LINE="$(grep -E '^- Warmup runs:' "$REPORT_MD" || true)"
RUNS="${RUNS_LINE##*: }"
WARMUPS="${WARMUP_LINE##*: }"
STAMP="$(basename "$RESULTS_DIR")"

cat > "$OUTPUT_SVG" <<EOF
<svg xmlns="http://www.w3.org/2000/svg" width="1440" height="900" viewBox="0 0 1440 900">
  <defs>
    <linearGradient id="bg" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" stop-color="#0F172A"/>
      <stop offset="100%" stop-color="#111827"/>
    </linearGradient>
    <linearGradient id="card" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" stop-color="#1F2937"/>
      <stop offset="100%" stop-color="#111827"/>
    </linearGradient>
  </defs>
  <rect width="1440" height="900" fill="url(#bg)"/>
  <text x="80" y="110" fill="#F9FAFB" font-family="Arial, sans-serif" font-size="54" font-weight="700">Agent Toolkit Overview</text>
  <text x="80" y="160" fill="#93C5FD" font-family="Arial, sans-serif" font-size="26">Latest scientific speedups from local benchmark run</text>
  <text x="80" y="205" fill="#9CA3AF" font-family="Arial, sans-serif" font-size="22">Run: $STAMP  |  runs: $RUNS  |  warmups: $WARMUPS</text>

  <rect x="80" y="250" rx="20" ry="20" width="400" height="210" fill="url(#card)" stroke="#334155" stroke-width="2"/>
  <text x="124" y="316" fill="#BFDBFE" font-family="Arial, sans-serif" font-size="24">Recursive Search</text>
  <text x="124" y="386" fill="#FFFFFF" font-family="Arial, sans-serif" font-size="54" font-weight="700">$(fmt2 "$SEARCH_SPEEDUP")x</text>
  <text x="124" y="430" fill="#9CA3AF" font-family="Arial, sans-serif" font-size="20">grep -R -> rg</text>

  <rect x="520" y="250" rx="20" ry="20" width="400" height="210" fill="url(#card)" stroke="#334155" stroke-width="2"/>
  <text x="564" y="316" fill="#BFDBFE" font-family="Arial, sans-serif" font-size="24">File Discovery</text>
  <text x="564" y="386" fill="#FFFFFF" font-family="Arial, sans-serif" font-size="54" font-weight="700">$(fmt2 "$FD_SPEEDUP")x</text>
  <text x="564" y="430" fill="#9CA3AF" font-family="Arial, sans-serif" font-size="20">find -> fd</text>

  <rect x="960" y="250" rx="20" ry="20" width="400" height="210" fill="url(#card)" stroke="#334155" stroke-width="2"/>
  <text x="1004" y="316" fill="#BFDBFE" font-family="Arial, sans-serif" font-size="24">Find + Search</text>
  <text x="1004" y="386" fill="#FFFFFF" font-family="Arial, sans-serif" font-size="54" font-weight="700">$(fmt2 "$PIPELINE_SPEEDUP")x</text>
  <text x="1004" y="430" fill="#9CA3AF" font-family="Arial, sans-serif" font-size="20">find+grep -> rg -g</text>

  <rect x="80" y="500" rx="20" ry="20" width="400" height="210" fill="url(#card)" stroke="#334155" stroke-width="2"/>
  <text x="124" y="566" fill="#BFDBFE" font-family="Arial, sans-serif" font-size="24">Structural Search</text>
  <text x="124" y="636" fill="#FFFFFF" font-family="Arial, sans-serif" font-size="54" font-weight="700">$(fmt2 "$AST_SPEEDUP")x</text>
  <text x="124" y="680" fill="#9CA3AF" font-family="Arial, sans-serif" font-size="20">rg -> ast-grep</text>

  <rect x="520" y="500" rx="20" ry="20" width="400" height="210" fill="url(#card)" stroke="#334155" stroke-width="2"/>
  <text x="564" y="566" fill="#BFDBFE" font-family="Arial, sans-serif" font-size="24">JSON Query</text>
  <text x="564" y="636" fill="#FFFFFF" font-family="Arial, sans-serif" font-size="54" font-weight="700">$(fmt2 "$JQ_SPEEDUP")x</text>
  <text x="564" y="680" fill="#9CA3AF" font-family="Arial, sans-serif" font-size="20">python -> jq</text>

  <rect x="960" y="500" rx="20" ry="20" width="400" height="210" fill="url(#card)" stroke="#334155" stroke-width="2"/>
  <text x="1004" y="566" fill="#BFDBFE" font-family="Arial, sans-serif" font-size="24">Search + Replace</text>
  <text x="1004" y="636" fill="#FFFFFF" font-family="Arial, sans-serif" font-size="54" font-weight="700">$(fmt2 "$SD_SPEEDUP")x</text>
  <text x="1004" y="680" fill="#9CA3AF" font-family="Arial, sans-serif" font-size="20">sed -> sd</text>

  <text x="80" y="760" fill="#E5E7EB" font-family="Arial, sans-serif" font-size="24">Source: benchmarks/results/$STAMP/results.tsv</text>
  <text x="80" y="800" fill="#9CA3AF" font-family="Arial, sans-serif" font-size="20">Generated by scripts/assets/generate-overview-asset.sh</text>
</svg>
EOF

if command -v magick >/dev/null 2>&1; then
  magick "$OUTPUT_SVG" "$OUTPUT_PNG" >/dev/null 2>&1 || true
fi

echo "Generated $OUTPUT_SVG"
if [[ -f "$OUTPUT_PNG" ]]; then
  echo "Updated $OUTPUT_PNG"
fi
