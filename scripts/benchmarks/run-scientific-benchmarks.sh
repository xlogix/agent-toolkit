#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

RUNS=25
WARMUP=5
KEEP_WORKDIR=0
FILTER_RAW=""
OUTPUT_BASE="$ROOT_DIR/benchmarks/results"

TOOL_LIST=(
  ripgrep ripgrep-all fd fzf bat eza zoxide jq yq simdjson gron ast-grep tree-sitter
  git-delta difftastic sd choose hyperfine httpie xh grpcurl watchexec just procs
  dust bandwhich bottom
)

usage() {
  cat <<'EOF'
Usage: bash scripts/benchmarks/run-scientific-benchmarks.sh [options]

Options:
  --runs <n>          Number of measured runs per command (default: 25)
  --warmup <n>        Warmup runs per command (default: 5)
  --filter <csv>      Run only specific case ids (comma-separated)
  --output-dir <dir>  Base output directory (default: benchmarks/results)
  --keep-workdir      Keep generated benchmark corpus
  -h, --help          Show help

Examples:
  bash scripts/benchmarks/run-scientific-benchmarks.sh
  bash scripts/benchmarks/run-scientific-benchmarks.sh --runs 40 --warmup 8
  bash scripts/benchmarks/run-scientific-benchmarks.sh --filter search-recursive,file-discovery
EOF
}

log() { printf '%s\n' "$*"; }
warn() { printf 'Warning: %s\n' "$*" >&2; }
err() { printf 'Error: %s\n' "$*" >&2; }

has_cmd() { command -v "$1" >/dev/null 2>&1; }

require_cmd() {
  local cmd="$1"
  if ! has_cmd "$cmd"; then
    err "Required command not found: $cmd"
    exit 1
  fi
}

is_filtered_case() {
  local case_id="$1"
  local token
  if [[ -z "$FILTER_RAW" ]]; then
    return 0
  fi
  for token in ${FILTER_RAW//,/ }; do
    [[ "$token" == "$case_id" ]] && return 0
  done
  return 1
}

to_ms() {
  awk -v s="$1" 'BEGIN { printf "%.3f", s * 1000 }'
}

ratio_or_na() {
  awk -v baseline="$1" -v current="$2" 'BEGIN {
    if (current <= 0 || baseline <= 0) {
      print "NA"
    } else {
      printf "%.3f", baseline / current
    }
  }'
}

record_case_tool() {
  local case_id="$1"
  local tool="$2"
  local status="$3"
  local reason="$4"
  printf '%s\t%s\t%s\t%s\n' "$case_id" "$tool" "$status" "$reason" >> "$COVERAGE_DETAILS_TSV"
}

run_case() {
  local case_id="$1"
  local description="$2"
  local tools_csv="$3"
  shift 3

  local tools=()
  local labels=()
  local commands=()
  local entry
  local json_path
  local case_tools_str
  local i result_count baseline_mean speedup
  local mean_s stddev_s median_s min_s max_s runs_n name

  is_filtered_case "$case_id" || return 0

  case_tools_str="${tools_csv//,/ }"
  for entry in $case_tools_str; do
    [[ -n "$entry" ]] && tools+=("$entry")
  done

  for entry in "$@"; do
    labels+=("${entry%%:::*}")
    commands+=("${entry#*:::}")
  done

  if [[ ${#labels[@]} -lt 2 ]]; then
    warn "Skipping case '$case_id': need at least 2 runnable alternatives."
    for entry in "${tools[@]}"; do
      record_case_tool "$case_id" "$entry" "skipped" "insufficient runnable alternatives"
    done
    printf '%s\t%s\t%s\n' "$case_id" "$description" "insufficient runnable alternatives" >> "$SKIPPED_CASES_TSV"
    return 0
  fi

  log "==> Case: $case_id"
  log "    $description"

  json_path="$CASE_JSON_DIR/${case_id}.json"
  local hf_args=(--warmup "$WARMUP" --runs "$RUNS" --export-json "$json_path")
  for i in "${!labels[@]}"; do
    hf_args+=(--command-name "${labels[$i]}" "${commands[$i]}")
  done

  if ! hyperfine "${hf_args[@]}" >/dev/null; then
    warn "Case '$case_id' failed during execution."
    for entry in "${tools[@]}"; do
      record_case_tool "$case_id" "$entry" "skipped" "execution failure"
    done
    printf '%s\t%s\t%s\n' "$case_id" "$description" "execution failure" >> "$SKIPPED_CASES_TSV"
    return 0
  fi

  baseline_mean="$(jq -r '.results[0].mean' "$json_path")"
  result_count="$(jq -r '.results | length' "$json_path")"
  printf '%s\t%s\n' "$case_id" "$description" >> "$CASE_META_TSV"

  for (( i=0; i<result_count; i++ )); do
    name="$(jq -r ".results[$i] | (.name // .command)" "$json_path")"
    mean_s="$(jq -r ".results[$i].mean" "$json_path")"
    stddev_s="$(jq -r ".results[$i].stddev" "$json_path")"
    median_s="$(jq -r ".results[$i].median" "$json_path")"
    min_s="$(jq -r ".results[$i].min" "$json_path")"
    max_s="$(jq -r ".results[$i].max" "$json_path")"
    runs_n="$(jq -r ".results[$i].times | length" "$json_path")"
    speedup="$(ratio_or_na "$baseline_mean" "$mean_s")"
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
      "$case_id" \
      "$name" \
      "$(to_ms "$mean_s")" \
      "$(to_ms "$stddev_s")" \
      "$(to_ms "$median_s")" \
      "$(to_ms "$min_s")" \
      "$(to_ms "$max_s")" \
      "$runs_n" \
      "$speedup" >> "$RESULTS_TSV"
  done

  for entry in "${tools[@]}"; do
    record_case_tool "$case_id" "$entry" "benchmarked" "ok"
  done
}

generate_dataset() {
  log "==> Creating benchmark dataset in $WORK_DIR"

  CORPUS_DIR="$WORK_DIR/corpus"
  TREE_DIR="$WORK_DIR/tree"
  JSON_DIR="$WORK_DIR/json"
  CODE_DIR="$WORK_DIR/code"
  HTTP_DIR="$WORK_DIR/http"
  mkdir -p "$CORPUS_DIR" "$TREE_DIR" "$JSON_DIR" "$CODE_DIR" "$HTTP_DIR"

  local i d f ext file

  for i in $(seq 1 9000); do
    file="$CORPUS_DIR/file_${i}.txt"
    printf 'sample file %s\n' "$i" > "$file"
    if (( i % 137 == 0 )); then
      printf 'AGENT_ACCELERATION_TOKEN\n' >> "$file"
    fi
  done

  for d in $(seq 1 220); do
    local dir="$TREE_DIR/dir_$d"
    mkdir -p "$dir"
    for f in $(seq 1 90); do
      ext="txt"
      if (( f % 3 == 0 )); then
        ext="ts"
      fi
      file="$dir/file_${f}.${ext}"
      printf 'const value = %s;\n' "$f" > "$file"
      if (( f % 21 == 0 )); then
        printf 'console.log("AGENT_FAST_PATH");\n' >> "$file"
      fi
    done
  done

  JSON_FILE="$JSON_DIR/data.json"
  {
    printf '{"items":['
    for i in $(seq 1 25000); do
      if [[ "$i" -gt 1 ]]; then
        printf ','
      fi
      printf '{"id":%s,"enabled":%s,"lang":"%s","payload":{"score":%s,"tag":"TAG_%s"}}' \
        "$i" \
        "$([[ $((i % 2)) -eq 0 ]] && echo true || echo false)" \
        "$([[ $((i % 3)) -eq 0 ]] && echo ts || echo js)" \
        "$((i % 100))" \
        "$i"
    done
    printf ']}'
  } > "$JSON_FILE"

  YAML_FILE="$JSON_DIR/data.yaml"
  {
    printf 'services:\n'
    for i in $(seq 1 4000); do
      printf '  - name: svc-%s\n' "$i"
      printf '    enabled: %s\n' "$([[ $((i % 2)) -eq 0 ]] && echo true || echo false)"
      printf '    tier: %s\n' "$([[ $((i % 3)) -eq 0 ]] && echo prod || echo dev)"
    done
  } > "$YAML_FILE"

  LIST_FILE="$WORK_DIR/list.txt"
  for i in $(seq 1 120000); do
    printf 'TOKEN-%06d\n' "$i"
  done > "$LIST_FILE"

  BIG_FILE="$WORK_DIR/big.log"
  for i in $(seq 1 160000); do
    printf 'log line %s AGENT_TOKEN_%s\n' "$i" "$((i % 10))"
  done > "$BIG_FILE"

  REPLACE_TEMPLATE="$WORK_DIR/replace-template.txt"
  REPLACE_WORK="$WORK_DIR/replace-work.txt"
  for i in $(seq 1 120000); do
    printf 'foo_%s = foo + foo\n' "$i"
  done > "$REPLACE_TEMPLATE"

  DIFF_OLD="$WORK_DIR/old.txt"
  DIFF_NEW="$WORK_DIR/new.txt"
  cp "$BIG_FILE" "$DIFF_OLD"
  cp "$BIG_FILE" "$DIFF_NEW"
  printf '\nEXTRA_LINE_FOR_DIFF\n' >> "$DIFF_NEW"

  TASK_DIR="$WORK_DIR/tasks"
  mkdir -p "$TASK_DIR"
  cat > "$TASK_DIR/Justfile" <<'EOF'
bench:
  @echo "bench"
EOF
  cat > "$TASK_DIR/Makefile" <<'EOF'
bench:
	@echo "bench"
EOF

  HTTP_FILE="$HTTP_DIR/data.json"
  cp "$JSON_FILE" "$HTTP_FILE"

  RGA_DIR="$WORK_DIR/docs"
  mkdir -p "$RGA_DIR"
  for i in $(seq 1 2500); do
    printf '# doc %s\nAGENT_DOC_TOKEN_%s\n' "$i" "$((i % 20))" > "$RGA_DIR/doc_$i.md"
  done

  if has_cmd zoxide; then
    export _ZO_DATA_DIR="$WORK_DIR/zoxide-db"
    mkdir -p "$_ZO_DATA_DIR"
    for d in "$TREE_DIR"/dir_*; do
      zoxide add "$d" >/dev/null 2>&1 || true
    done
  fi
}

start_http_server() {
  HTTP_PORT=18777
  HTTP_SERVER_PID=""
  if ! has_cmd python3; then
    return 0
  fi
  python3 -m http.server "$HTTP_PORT" --bind 127.0.0.1 --directory "$HTTP_DIR" >/dev/null 2>&1 &
  HTTP_SERVER_PID="$!"
  sleep 1
}

stop_http_server() {
  if [[ -n "${HTTP_SERVER_PID:-}" ]]; then
    kill "$HTTP_SERVER_PID" >/dev/null 2>&1 || true
  fi
}

render_reports() {
  local md="$REPORT_DIR/report.md"
  local coverage_md="$REPORT_DIR/coverage.md"
  local case_id desc reason
  local line
  local tool
  local status reason_for_tool case_for_tool

  {
    printf '# Scientific Benchmark Report\n\n'
    printf -- '- Generated: %s\n' "$(date -u '+%Y-%m-%d %H:%M:%S UTC')"
    printf -- '- Runs per command: %s\n' "$RUNS"
    printf -- '- Warmup runs: %s\n' "$WARMUP"
    printf -- '- Host: %s\n' "$(uname -a)"
    printf -- '- Hyperfine: %s\n\n' "$(hyperfine --version)"

    if [[ -s "$SKIPPED_CASES_TSV" ]]; then
      printf '## Skipped Cases\n\n'
      printf '| Case | Reason |\n|---|---|\n'
      while IFS=$'\t' read -r case_id desc reason; do
        printf "| \`%s\` | %s |\n" "$case_id" "$reason"
      done < "$SKIPPED_CASES_TSV"
      printf '\n'
    fi

    printf '## Results\n\n'
    while IFS=$'\t' read -r case_id desc; do
      printf '### %s\n\n' "$case_id"
      printf '%s\n\n' "$desc"
      printf '| Command | Mean (ms) | Stddev (ms) | Median (ms) | Min (ms) | Max (ms) | Runs | Speedup vs baseline |\n'
      printf '|---|---:|---:|---:|---:|---:|---:|---:|\n'
      awk -F'\t' -v c="$case_id" '
        $1 == c {
          printf "| `%s` | %s | %s | %s | %s | %s | %s | %s |\n", $2, $3, $4, $5, $6, $7, $8, $9
        }
      ' "$RESULTS_TSV"
      printf '\n'
    done < "$CASE_META_TSV"
  } > "$md"

  for tool in "${TOOL_LIST[@]}"; do
    if ! awk -F'\t' -v t="$tool" '$2 == t { found = 1 } END { exit(found ? 0 : 1) }' "$COVERAGE_DETAILS_TSV"; then
      printf 'not-covered\t%s\tn/a\tno benchmark case implemented yet\n' "$tool" >> "$COVERAGE_DETAILS_TSV"
    fi
  done

  {
    printf '# Tool Coverage\n\n'
    printf '| Tool | Status | Case | Note |\n'
    printf '|---|---|---|---|\n'
    for tool in "${TOOL_LIST[@]}"; do
      line="$(awk -F'\t' -v t="$tool" '
        $2 == t && $3 == "benchmarked" { print $3 "\t" $1 "\t" $4; found = 1; exit }
        END {
          if (!found) {
            # prefer skipped over not-covered
          }
        }
      ' "$COVERAGE_DETAILS_TSV")"

      if [[ -z "$line" ]]; then
        line="$(awk -F'\t' -v t="$tool" '
          $2 == t && $3 == "skipped" { print $3 "\t" $1 "\t" $4; found = 1; exit }
        ' "$COVERAGE_DETAILS_TSV")"
      fi

      if [[ -z "$line" ]]; then
        line="$(awk -F'\t' -v t="$tool" '
          $2 == t { print $3 "\t" $1 "\t" $4; exit }
        ' "$COVERAGE_DETAILS_TSV")"
      fi

      status="${line%%$'\t'*}"
      line="${line#*$'\t'}"
      case_for_tool="${line%%$'\t'*}"
      reason_for_tool="${line#*$'\t'}"

      printf "| \`%s\` | %s | \`%s\` | %s |\n" "$tool" "$status" "$case_for_tool" "$reason_for_tool"
    done
  } > "$coverage_md"

  log
  log "==> Reports"
  log "  - $md"
  log "  - $coverage_md"
  log "  - raw case JSON: $CASE_JSON_DIR"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --runs)
      shift
      RUNS="${1:-}"
      ;;
    --warmup)
      shift
      WARMUP="${1:-}"
      ;;
    --filter)
      shift
      FILTER_RAW="${1:-}"
      ;;
    --output-dir)
      shift
      OUTPUT_BASE="${1:-}"
      ;;
    --keep-workdir)
      KEEP_WORKDIR=1
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      err "Unknown argument: $1"
      usage
      exit 1
      ;;
  esac
  shift
done

require_cmd hyperfine
require_cmd jq
require_cmd awk

TIMESTAMP="$(date '+%Y%m%d')"
REPORT_DIR="$OUTPUT_BASE/$TIMESTAMP"
CASE_JSON_DIR="$REPORT_DIR/cases"
if [[ -d "$REPORT_DIR" ]]; then
  rm -rf "$REPORT_DIR"
fi
mkdir -p "$CASE_JSON_DIR"

RESULTS_TSV="$REPORT_DIR/results.tsv"
CASE_META_TSV="$REPORT_DIR/cases.tsv"
SKIPPED_CASES_TSV="$REPORT_DIR/skipped-cases.tsv"
COVERAGE_DETAILS_TSV="$REPORT_DIR/coverage-details.tsv"
printf 'case_id\tcommand\tmean_ms\tstddev_ms\tmedian_ms\tmin_ms\tmax_ms\truns\tspeedup_vs_baseline\n' > "$RESULTS_TSV"
: > "$CASE_META_TSV"
: > "$SKIPPED_CASES_TSV"
: > "$COVERAGE_DETAILS_TSV"

WORK_DIR="$(mktemp -d -t agent-toolkit-bench.XXXXXX)"
if [[ "$KEEP_WORKDIR" -eq 1 ]]; then
  trap 'stop_http_server' EXIT
else
  trap 'stop_http_server; rm -rf "$WORK_DIR"' EXIT
fi

FD_BIN=""
if has_cmd fd; then
  FD_BIN="fd"
elif has_cmd fdfind; then
  FD_BIN="fdfind"
fi

DIFFT_BIN=""
if has_cmd difft; then
  DIFFT_BIN="difft"
elif has_cmd difftastic; then
  DIFFT_BIN="difftastic"
fi

SIMDJSON_BIN=""
if has_cmd json2json; then
  SIMDJSON_BIN="json2json"
fi

generate_dataset
start_http_server

SEARCH_BASELINE="grep -R --line-number 'AGENT_ACCELERATION_TOKEN' '$CORPUS_DIR' >/dev/null"
SEARCH_RG="rg --line-number 'AGENT_ACCELERATION_TOKEN' '$CORPUS_DIR' >/dev/null"
run_case "search-recursive" \
  "Recursive content search in corpus directory." \
  "ripgrep" \
  "grep:::${SEARCH_BASELINE}" \
  "rg:::${SEARCH_RG}"

if has_cmd rga && has_cmd rg; then
  run_case "search-docs-ripgrep-all" \
    "Search across mixed docs corpus using ripgrep-all vs ripgrep." \
    "ripgrep-all,ripgrep" \
    "rg:::rg 'AGENT_DOC_TOKEN_7' '$RGA_DIR' >/dev/null" \
    "rga:::rga 'AGENT_DOC_TOKEN_7' '$RGA_DIR' >/dev/null"
else
  record_case_tool "search-docs-ripgrep-all" "ripgrep-all" "skipped" "missing rga or rg"
  printf '%s\t%s\t%s\n' "search-docs-ripgrep-all" "Search across mixed docs corpus using ripgrep-all vs ripgrep." "missing rga or rg" >> "$SKIPPED_CASES_TSV"
fi

if [[ -n "$FD_BIN" ]]; then
  run_case "file-discovery" \
    "Find TypeScript files in a deep tree." \
    "fd" \
    "find:::find '$TREE_DIR' -type f -name '*.ts' >/dev/null" \
    "${FD_BIN}:::${FD_BIN} -e ts . '$TREE_DIR' >/dev/null"
else
  record_case_tool "file-discovery" "fd" "skipped" "missing fd/fdfind"
  printf '%s\t%s\t%s\n' "file-discovery" "Find TypeScript files in a deep tree." "missing fd/fdfind" >> "$SKIPPED_CASES_TSV"
fi

run_case "find-then-search" \
  "Find files then match content." \
  "ripgrep" \
  "find+grep:::find '$TREE_DIR' -type f -name '*.ts' -exec grep -l 'AGENT_FAST_PATH' {} + >/dev/null" \
  "rg-glob:::rg -g '*.ts' -l 'AGENT_FAST_PATH' '$TREE_DIR' >/dev/null"

if has_cmd fzf; then
  run_case "fuzzy-filter" \
    "Filter large candidate list to a target token." \
    "fzf,ripgrep" \
    "rg:::rg '^TOKEN-099999$' '$LIST_FILE' >/dev/null" \
    "fzf:::fzf --filter 'TOKEN-099999' < '$LIST_FILE' >/dev/null"
else
  record_case_tool "fuzzy-filter" "fzf" "skipped" "missing fzf"
  printf '%s\t%s\t%s\n' "fuzzy-filter" "Filter large candidate list to a target token." "missing fzf" >> "$SKIPPED_CASES_TSV"
fi

if has_cmd bat; then
  run_case "file-inspection" \
    "Inspect large log files." \
    "bat" \
    "cat:::cat '$BIG_FILE' >/dev/null" \
    "bat:::bat --plain --paging=never '$BIG_FILE' >/dev/null"
else
  record_case_tool "file-inspection" "bat" "skipped" "missing bat"
  printf '%s\t%s\t%s\n' "file-inspection" "Inspect large log files." "missing bat" >> "$SKIPPED_CASES_TSV"
fi

if has_cmd eza; then
  run_case "tree-listing" \
    "Recursive directory listing visibility workload." \
    "eza" \
    "ls:::ls -R '$TREE_DIR' >/dev/null" \
    "eza:::eza -R '$TREE_DIR' >/dev/null"
else
  record_case_tool "tree-listing" "eza" "skipped" "missing eza"
  printf '%s\t%s\t%s\n' "tree-listing" "Recursive directory listing visibility workload." "missing eza" >> "$SKIPPED_CASES_TSV"
fi

if has_cmd zoxide; then
  run_case "directory-jump-query" \
    "Directory lookup from jump database." \
    "zoxide" \
    "find:::find '$TREE_DIR' -type d -name 'dir_120' | head -n 1 >/dev/null" \
    "zoxide:::zoxide query dir_120 >/dev/null"
else
  record_case_tool "directory-jump-query" "zoxide" "skipped" "missing zoxide"
  printf '%s\t%s\t%s\n' "directory-jump-query" "Directory lookup from jump database." "missing zoxide" >> "$SKIPPED_CASES_TSV"
fi

if has_cmd python3; then
  run_case "json-query" \
    "Structured JSON query and filtering." \
    "jq" \
    "python3:::python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); [x[\"id\"] for x in d[\"items\"] if x[\"enabled\"] and x[\"lang\"]==\"ts\"]' '$JSON_FILE' >/dev/null" \
    "jq:::jq '.items[] | select(.enabled and .lang==\"ts\") | .id' '$JSON_FILE' >/dev/null"
else
  record_case_tool "json-query" "jq" "skipped" "missing python3 baseline"
  printf '%s\t%s\t%s\n' "json-query" "Structured JSON query and filtering." "missing python3 baseline" >> "$SKIPPED_CASES_TSV"
fi

if has_cmd yq; then
  run_case "yaml-query" \
    "YAML query workload versus text filtering baseline." \
    "yq" \
    "grep:::grep -c 'enabled: true' '$YAML_FILE' >/dev/null" \
    "yq:::yq '.services[] | select(.enabled == true) | .name' '$YAML_FILE' >/dev/null"
else
  record_case_tool "yaml-query" "yq" "skipped" "missing yq"
  printf '%s\t%s\t%s\n' "yaml-query" "YAML query workload versus text filtering baseline." "missing yq" >> "$SKIPPED_CASES_TSV"
fi

if [[ -n "$SIMDJSON_BIN" ]]; then
  run_case "json-parse-throughput" \
    "Raw JSON parse/normalize throughput." \
    "simdjson,jq" \
    "jq:::jq -c . '$JSON_FILE' >/dev/null" \
    "${SIMDJSON_BIN}:::${SIMDJSON_BIN} '$JSON_FILE' >/dev/null"
else
  record_case_tool "json-parse-throughput" "simdjson" "skipped" "missing json2json (simdjson tools)"
  printf '%s\t%s\t%s\n' "json-parse-throughput" "Raw JSON parse/normalize throughput." "missing json2json (simdjson tools)" >> "$SKIPPED_CASES_TSV"
fi

if has_cmd gron; then
  run_case "json-flatten" \
    "Flatten nested JSON to search-friendly lines." \
    "gron,jq" \
    "jq-flatten:::jq -r 'paths(scalars) as \$p | \"\(\$p|join(\".\"))=\(getpath(\$p))\"' '$JSON_FILE' >/dev/null" \
    "gron:::gron '$JSON_FILE' >/dev/null"
else
  record_case_tool "json-flatten" "gron" "skipped" "missing gron"
  printf '%s\t%s\t%s\n' "json-flatten" "Flatten nested JSON to search-friendly lines." "missing gron" >> "$SKIPPED_CASES_TSV"
fi

if has_cmd ast-grep; then
  run_case "structural-search" \
    "Code search with regex baseline vs structural pattern matching." \
    "ast-grep,ripgrep" \
    "rg:::rg -n 'console\\.log\\(' '$TREE_DIR' >/dev/null" \
    "ast-grep:::ast-grep --pattern 'console.log(\$\$\$)' '$TREE_DIR' >/dev/null"
else
  record_case_tool "structural-search" "ast-grep" "skipped" "missing ast-grep"
  printf '%s\t%s\t%s\n' "structural-search" "Code search with regex baseline vs structural pattern matching." "missing ast-grep" >> "$SKIPPED_CASES_TSV"
fi

if has_cmd tree-sitter; then
  run_case "syntax-parse" \
    "Syntax parsing throughput." \
    "tree-sitter,ast-grep" \
    "cat:::cat '$TREE_DIR/dir_1/file_3.ts' >/dev/null" \
    "tree-sitter:::tree-sitter parse '$TREE_DIR/dir_1/file_3.ts' >/dev/null"
else
  record_case_tool "syntax-parse" "tree-sitter" "skipped" "missing tree-sitter"
  printf '%s\t%s\t%s\n' "syntax-parse" "Syntax parsing throughput." "missing tree-sitter" >> "$SKIPPED_CASES_TSV"
fi

if has_cmd delta; then
  run_case "diff-rendering-delta" \
    "Diff rendering readability pipeline." \
    "git-delta" \
    "git-diff:::git --no-pager diff --no-index -- '$DIFF_OLD' '$DIFF_NEW' >/dev/null || true" \
    "git+delta:::git --no-pager diff --no-index -- '$DIFF_OLD' '$DIFF_NEW' | delta >/dev/null || true"
else
  record_case_tool "diff-rendering-delta" "git-delta" "skipped" "missing delta"
  printf '%s\t%s\t%s\n' "diff-rendering-delta" "Diff rendering readability pipeline." "missing delta" >> "$SKIPPED_CASES_TSV"
fi

if [[ -n "$DIFFT_BIN" ]]; then
  run_case "diff-rendering-difftastic" \
    "Semantic diff rendering versus standard diff." \
    "difftastic" \
    "diff:::diff -u '$DIFF_OLD' '$DIFF_NEW' >/dev/null || true" \
    "${DIFFT_BIN}:::${DIFFT_BIN} '$DIFF_OLD' '$DIFF_NEW' >/dev/null || true"
else
  record_case_tool "diff-rendering-difftastic" "difftastic" "skipped" "missing difftastic/difft"
  printf '%s\t%s\t%s\n' "diff-rendering-difftastic" "Semantic diff rendering versus standard diff." "missing difftastic/difft" >> "$SKIPPED_CASES_TSV"
fi

if has_cmd sd; then
  run_case "search-replace" \
    "Bulk text replacement." \
    "sd" \
    "sed:::cp '$REPLACE_TEMPLATE' '$REPLACE_WORK' && sed -i.bak 's/foo/bar/g' '$REPLACE_WORK' && rm -f '$REPLACE_WORK.bak'" \
    "sd:::cp '$REPLACE_TEMPLATE' '$REPLACE_WORK' && sd 'foo' 'bar' '$REPLACE_WORK' >/dev/null"
else
  record_case_tool "search-replace" "sd" "skipped" "missing sd"
  printf '%s\t%s\t%s\n' "search-replace" "Bulk text replacement." "missing sd" >> "$SKIPPED_CASES_TSV"
fi

if has_cmd choose; then
  run_case "pipeline-select" \
    "Pipeline selection utility throughput." \
    "choose" \
    "awk:::awk 'NR % 2 == 0 { print }' '$LIST_FILE' >/dev/null" \
    "choose:::choose '1/2' < '$LIST_FILE' >/dev/null"
else
  record_case_tool "pipeline-select" "choose" "skipped" "missing choose"
  printf '%s\t%s\t%s\n' "pipeline-select" "Pipeline selection utility throughput." "missing choose" >> "$SKIPPED_CASES_TSV"
fi

# hyperfine itself is the benchmarking engine, not a compared workload tool.
record_case_tool "meta" "hyperfine" "benchmarked" "used as benchmark runner"

HTTP_URL="http://127.0.0.1:${HTTP_PORT:-18777}/data.json"
HTTP_ENTRIES=("curl:::curl -s '$HTTP_URL' >/dev/null")
HTTP_TOOLS=()
if has_cmd http; then
  HTTP_TOOLS+=("httpie")
  HTTP_ENTRIES+=("httpie:::http --ignore-stdin --check-status GET '$HTTP_URL' >/dev/null")
else
  record_case_tool "http-requests" "httpie" "skipped" "missing httpie (http)"
fi
if has_cmd xh; then
  HTTP_TOOLS+=("xh")
  HTTP_ENTRIES+=("xh:::xh --ignore-stdin GET '$HTTP_URL' >/dev/null")
else
  record_case_tool "http-requests" "xh" "skipped" "missing xh"
fi
HTTP_TOOLS_CSV=""
if [[ ${#HTTP_TOOLS[@]} -gt 0 ]]; then
  HTTP_TOOLS_CSV="$(IFS=,; echo "${HTTP_TOOLS[*]}")"
fi
run_case "http-requests" \
  "Local HTTP request latency and throughput." \
  "$HTTP_TOOLS_CSV" \
  "${HTTP_ENTRIES[@]}"

record_case_tool "grpc-url" "grpcurl" "skipped" "requires reproducible grpc server fixture"
printf '%s\t%s\t%s\n' "grpc-url" "gRPC request benchmarking." "requires reproducible grpc server fixture" >> "$SKIPPED_CASES_TSV"

record_case_tool "watchexec" "watchexec" "skipped" "interactive/watch workload not stable in single-shot benchmarks"
printf '%s\t%s\t%s\n' "watchexec" "File watch and rerun latency." "interactive/watch workload not stable in single-shot benchmarks" >> "$SKIPPED_CASES_TSV"

if has_cmd just; then
  run_case "task-runner" \
    "Task-runner invocation overhead." \
    "just" \
    "make:::make -s -f '$TASK_DIR/Makefile' bench >/dev/null" \
    "just:::just --justfile '$TASK_DIR/Justfile' bench >/dev/null"
else
  record_case_tool "task-runner" "just" "skipped" "missing just"
  printf '%s\t%s\t%s\n' "task-runner" "Task-runner invocation overhead." "missing just" >> "$SKIPPED_CASES_TSV"
fi

if has_cmd procs; then
  run_case "process-list" \
    "Process listing workload." \
    "procs" \
    "ps:::ps aux >/dev/null" \
    "procs:::procs >/dev/null"
else
  record_case_tool "process-list" "procs" "skipped" "missing procs"
  printf '%s\t%s\t%s\n' "process-list" "Process listing workload." "missing procs" >> "$SKIPPED_CASES_TSV"
fi

if has_cmd dust; then
  run_case "disk-usage" \
    "Disk usage summarization workload." \
    "dust" \
    "du:::du -sk '$TREE_DIR' >/dev/null" \
    "dust:::dust '$TREE_DIR' >/dev/null"
else
  record_case_tool "disk-usage" "dust" "skipped" "missing dust"
  printf '%s\t%s\t%s\n' "disk-usage" "Disk usage summarization workload." "missing dust" >> "$SKIPPED_CASES_TSV"
fi

record_case_tool "network-process-usage" "bandwhich" "skipped" "requires elevated/network fixture for reproducible results"
printf '%s\t%s\t%s\n' "network-process-usage" "Per-process network usage." "requires elevated/network fixture for reproducible results" >> "$SKIPPED_CASES_TSV"

record_case_tool "system-monitor" "bottom" "skipped" "interactive TUI; no stable single-shot benchmark"
printf '%s\t%s\t%s\n' "system-monitor" "System monitor responsiveness." "interactive TUI; no stable single-shot benchmark" >> "$SKIPPED_CASES_TSV"

render_reports
log
log "==> Raw outputs in: $REPORT_DIR"
if [[ "$KEEP_WORKDIR" -eq 1 ]]; then
  log "==> Dataset retained at: $WORK_DIR"
fi
