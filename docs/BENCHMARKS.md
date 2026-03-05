# Benchmarks

This document contains local benchmark results for core search/discovery workflows that LLM coding agents execute repeatedly.

## Test environment

- Date: 2026-03-04
- OS: macOS 26.3 (Darwin 25.3.0)
- CPU: Apple M3 Pro
- Tooling: `hyperfine 1.20.0`
- Data sets:
  - `corpus`: 12,000 text files
  - `tree`: 48,000 files (mixed `.ts` and `.txt`)

## Results

| Workflow | Baseline | Agent tool | Mean time baseline | Mean time agent tool | Speedup |
|---|---|---|---:|---:|---:|
| Recursive content search | `grep -R` | `rg` | 375.8 ms | 143.6 ms | **2.62x** |
| File discovery by extension | `find -name "*.ts"` | `fd -e ts` | 86.6 ms | 35.1 ms | **2.46x** |
| Find files then search content | `find ... -exec grep` | `rg -g "*.ts"` | 532.7 ms | 154.9 ms | **3.44x** |

## Reproduce locally

Use this command sequence:

```bash
bench_root=/tmp/agent-tools-bench-$(date +%s)
mkdir -p "$bench_root/corpus" "$bench_root/tree" "$bench_root/data"

# 12k text files
for i in $(seq 1 12000); do
  f="$bench_root/corpus/file_${i}.txt"
  printf 'This is sample file %s\n' "$i" > "$f"
  if (( i % 157 == 0 )); then printf 'AGENT_ACCELERATION_TOKEN\n' >> "$f"; fi
done

# 48k mixed files
for d in $(seq 1 400); do
  dir="$bench_root/tree/dir_$d"; mkdir -p "$dir"
  for f in $(seq 1 120); do
    ext="txt"; if (( f % 3 == 0 )); then ext="ts"; fi
    file="$dir/file_${f}.${ext}"
    printf 'const value=%s;\n' "$f" > "$file"
    if (( f % 23 == 0 )); then printf 'AGENT_FAST_PATH\n' >> "$file"; fi
  done
done

hyperfine --warmup 3 --runs 12 \
  'grep -R --line-number "AGENT_ACCELERATION_TOKEN" '"$bench_root"'/corpus >/dev/null' \
  'rg --line-number "AGENT_ACCELERATION_TOKEN" '"$bench_root"'/corpus >/dev/null'

hyperfine --warmup 3 --runs 12 \
  'find '"$bench_root"'/tree -type f -name "*.ts" >/dev/null' \
  'fd -e ts . '"$bench_root"'/tree >/dev/null'

hyperfine --warmup 3 --runs 12 \
  'find '"$bench_root"'/tree -type f -name "*.ts" -exec grep -l "AGENT_FAST_PATH" {} + >/dev/null' \
  'rg -g "*.ts" -l "AGENT_FAST_PATH" '"$bench_root"'/tree >/dev/null'
```

## Notes

- Speedups vary by filesystem, CPU, and project shape.
- These results focus on repeated agent loops (search, filter, locate), where cumulative wins are significant over long sessions.
