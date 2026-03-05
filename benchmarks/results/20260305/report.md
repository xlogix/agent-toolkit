# Scientific Benchmark Report

- Generated: 2026-03-05 14:36:35 UTC
- Runs per command: 40
- Warmup runs: 8
- Host: Darwin Abhis-Mac-2.local 25.3.0 Darwin Kernel Version 25.3.0: Wed Jan 28 20:54:22 PST 2026; root:xnu-12377.81.4~5/RELEASE_ARM64_T6030 arm64
- Hyperfine: hyperfine 1.20.0

## Skipped Cases

| Case | Reason |
|---|---|
| `json-parse-throughput` | missing json2json (simdjson tools) |
| `syntax-parse` | missing tree-sitter |
| `pipeline-select` | missing choose |
| `grpc-url` | requires reproducible grpc server fixture |
| `watchexec` | interactive/watch workload not stable in single-shot benchmarks |
| `process-list` | missing procs |
| `disk-usage` | missing dust |
| `network-process-usage` | requires elevated/network fixture for reproducible results |
| `system-monitor` | interactive TUI; no stable single-shot benchmark |

## Results

### search-recursive

Recursive content search in corpus directory.

| Command | Mean (ms) | Stddev (ms) | Median (ms) | Min (ms) | Max (ms) | Runs | Speedup vs baseline |
|---|---:|---:|---:|---:|---:|---:|---:|
| `grep` | 268.435 | 10.956 | 265.620 | 260.805 | 328.130 | 40 | 1.000 |
| `rg` | 94.992 | 2.070 | 94.997 | 90.607 | 99.684 | 40 | 2.826 |

### search-docs-ripgrep-all

Search across mixed docs corpus using ripgrep-all vs ripgrep.

| Command | Mean (ms) | Stddev (ms) | Median (ms) | Min (ms) | Max (ms) | Runs | Speedup vs baseline |
|---|---:|---:|---:|---:|---:|---:|---:|
| `rg` | 26.777 | 0.626 | 26.845 | 25.274 | 28.008 | 40 | 1.000 |
| `rga` | 30.922 | 0.791 | 31.028 | 29.492 | 32.513 | 40 | 0.866 |

### file-discovery

Find TypeScript files in a deep tree.

| Command | Mean (ms) | Stddev (ms) | Median (ms) | Min (ms) | Max (ms) | Runs | Speedup vs baseline |
|---|---:|---:|---:|---:|---:|---:|---:|
| `find` | 33.123 | 0.565 | 33.013 | 32.242 | 34.747 | 40 | 1.000 |
| `fd` | 17.851 | 0.977 | 17.779 | 15.994 | 20.275 | 40 | 1.856 |

### find-then-search

Find files then match content.

| Command | Mean (ms) | Stddev (ms) | Median (ms) | Min (ms) | Max (ms) | Runs | Speedup vs baseline |
|---|---:|---:|---:|---:|---:|---:|---:|
| `find+grep` | 239.188 | 5.197 | 237.688 | 234.576 | 257.676 | 40 | 1.000 |
| `rg-glob` | 67.071 | 0.887 | 67.022 | 65.219 | 68.986 | 40 | 3.566 |

### fuzzy-filter

Filter large candidate list to a target token.

| Command | Mean (ms) | Stddev (ms) | Median (ms) | Min (ms) | Max (ms) | Runs | Speedup vs baseline |
|---|---:|---:|---:|---:|---:|---:|---:|
| `rg` | 4.000 | 0.222 | 3.990 | 3.506 | 4.465 | 40 | 1.000 |
| `fzf` | 12.412 | 1.845 | 11.714 | 10.221 | 17.697 | 40 | 0.322 |

### file-inspection

Inspect large log files.

| Command | Mean (ms) | Stddev (ms) | Median (ms) | Min (ms) | Max (ms) | Runs | Speedup vs baseline |
|---|---:|---:|---:|---:|---:|---:|---:|
| `cat` | 2.050 | 0.310 | 2.050 | 1.447 | 2.552 | 40 | 1.000 |
| `bat` | 83.098 | 0.620 | 83.065 | 81.837 | 84.948 | 40 | 0.025 |

### tree-listing

Recursive directory listing visibility workload.

| Command | Mean (ms) | Stddev (ms) | Median (ms) | Min (ms) | Max (ms) | Runs | Speedup vs baseline |
|---|---:|---:|---:|---:|---:|---:|---:|
| `ls` | 37.904 | 0.383 | 37.871 | 37.324 | 38.785 | 40 | 1.000 |
| `eza` | 90.343 | 0.764 | 90.458 | 89.128 | 92.440 | 40 | 0.420 |

### directory-jump-query

Directory lookup from jump database.

| Command | Mean (ms) | Stddev (ms) | Median (ms) | Min (ms) | Max (ms) | Runs | Speedup vs baseline |
|---|---:|---:|---:|---:|---:|---:|---:|
| `find` | 26.744 | 0.411 | 26.848 | 25.742 | 27.576 | 40 | 1.000 |
| `zoxide` | 7.721 | 0.648 | 7.618 | 6.238 | 9.239 | 40 | 3.464 |

### json-query

Structured JSON query and filtering.

| Command | Mean (ms) | Stddev (ms) | Median (ms) | Min (ms) | Max (ms) | Runs | Speedup vs baseline |
|---|---:|---:|---:|---:|---:|---:|---:|
| `python3` | 177.357 | 30.899 | 161.196 | 154.561 | 312.395 | 40 | 1.000 |
| `jq` | 41.251 | 0.244 | 41.231 | 40.782 | 41.920 | 40 | 4.299 |

### yaml-query

YAML query workload versus text filtering baseline.

| Command | Mean (ms) | Stddev (ms) | Median (ms) | Min (ms) | Max (ms) | Runs | Speedup vs baseline |
|---|---:|---:|---:|---:|---:|---:|---:|
| `grep` | 3.491 | 0.075 | 3.487 | 3.341 | 3.665 | 40 | 1.000 |
| `yq` | 33.579 | 0.344 | 33.526 | 32.963 | 34.473 | 40 | 0.104 |

### json-flatten

Flatten nested JSON to search-friendly lines.

| Command | Mean (ms) | Stddev (ms) | Median (ms) | Min (ms) | Max (ms) | Runs | Speedup vs baseline |
|---|---:|---:|---:|---:|---:|---:|---:|
| `jq-flatten` | 590.274 | 3.294 | 589.291 | 586.067 | 601.448 | 40 | 1.000 |
| `gron` | 245.565 | 8.157 | 243.203 | 240.488 | 281.938 | 40 | 2.404 |

### structural-search

Code search with regex baseline vs structural pattern matching.

| Command | Mean (ms) | Stddev (ms) | Median (ms) | Min (ms) | Max (ms) | Runs | Speedup vs baseline |
|---|---:|---:|---:|---:|---:|---:|---:|
| `rg` | 345.147 | 78.698 | 326.300 | 258.759 | 675.610 | 40 | 1.000 |
| `ast-grep` | 66.468 | 1.282 | 66.555 | 64.141 | 70.099 | 40 | 5.193 |

### diff-rendering-delta

Diff rendering readability pipeline.

| Command | Mean (ms) | Stddev (ms) | Median (ms) | Min (ms) | Max (ms) | Runs | Speedup vs baseline |
|---|---:|---:|---:|---:|---:|---:|---:|
| `git-diff` | 72.916 | 1.005 | 72.480 | 71.792 | 75.603 | 40 | 1.000 |
| `git+delta` | 74.106 | 0.971 | 73.718 | 73.101 | 76.557 | 40 | 0.984 |

### diff-rendering-difftastic

Semantic diff rendering versus standard diff.

| Command | Mean (ms) | Stddev (ms) | Median (ms) | Min (ms) | Max (ms) | Runs | Speedup vs baseline |
|---|---:|---:|---:|---:|---:|---:|---:|
| `diff` | 15.539 | 0.227 | 15.527 | 15.088 | 16.324 | 40 | 1.000 |
| `difft` | 269.275 | 3.506 | 268.860 | 262.811 | 277.076 | 40 | 0.058 |

### search-replace

Bulk text replacement.

| Command | Mean (ms) | Stddev (ms) | Median (ms) | Min (ms) | Max (ms) | Runs | Speedup vs baseline |
|---|---:|---:|---:|---:|---:|---:|---:|
| `sed` | 73.560 | 1.184 | 73.334 | 72.462 | 79.314 | 40 | 1.000 |
| `sd` | 29.675 | 0.805 | 29.638 | 28.262 | 32.575 | 40 | 2.479 |

### http-requests

Local HTTP request latency and throughput.

| Command | Mean (ms) | Stddev (ms) | Median (ms) | Min (ms) | Max (ms) | Runs | Speedup vs baseline |
|---|---:|---:|---:|---:|---:|---:|---:|
| `curl` | 10.899 | 0.724 | 10.933 | 9.875 | 13.211 | 40 | 1.000 |
| `httpie` | 161.488 | 7.008 | 160.154 | 155.578 | 199.869 | 40 | 0.067 |

### task-runner

Task-runner invocation overhead.

| Command | Mean (ms) | Stddev (ms) | Median (ms) | Min (ms) | Max (ms) | Runs | Speedup vs baseline |
|---|---:|---:|---:|---:|---:|---:|---:|
| `make` | 19.437 | 35.353 | 8.387 | 7.530 | 226.400 | 40 | 1.000 |
| `just` | 13.607 | 7.545 | 10.755 | 9.065 | 41.304 | 40 | 1.428 |

