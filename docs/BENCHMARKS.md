# Benchmarks

This repo includes a reproducible benchmark harness designed for repeated runs, warmups, per-command averages, standard deviation, and raw JSON exports.

## Scientific harness

Run:

```bash
bash scripts/benchmarks/run-scientific-benchmarks.sh
```

Recommended stronger run:

```bash
bash scripts/benchmarks/run-scientific-benchmarks.sh --runs 40 --warmup 8
```

Outputs are written under:

```text
benchmarks/results/<YYYYMMDD>/
```

By default, repeated runs on the same day overwrite that date folder.

Generated artifacts:

- `report.md`: per-case benchmark results (mean/stddev/median/min/max/speedup)
- `coverage.md`: per-tool benchmark status (benchmarked/skipped/not-covered with reason)
- `results.tsv`: machine-friendly flattened metrics
- `cases/*.json`: raw `hyperfine` JSON output per case
- `skipped-cases.tsv`: skipped case reasons

## Methodology

The harness creates deterministic local datasets, then uses `hyperfine` with configurable warmup and run counts.

Default parameters:

- warmup runs: `5`
- measured runs: `25`
- benchmark engine: `hyperfine`
- metrics: mean, stddev, median, min, max, runs, speedup vs baseline

## Coverage model

Every tool in the requested stack is explicitly tracked:

- Benchmarked: deterministic case ran successfully.
- Skipped: case exists but was not runnable (missing binary, missing fixture, interactive-only, privileged runtime, etc.).
- Not-covered: no stable benchmark case is defined yet.

## Example targeted runs

Run only specific cases:

```bash
bash scripts/benchmarks/run-scientific-benchmarks.sh --filter search-recursive,file-discovery,json-query
```

Keep generated corpus for deep analysis:

```bash
bash scripts/benchmarks/run-scientific-benchmarks.sh --keep-workdir
```

## Notes

- Benchmarks are host-dependent (CPU, filesystem, thermal state, background load).
- Compare results across runs on the same host profile.
- Prefer medians/standard deviation interpretation for noisy workloads, not single-run means.
