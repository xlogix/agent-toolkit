# Tool Coverage

| Tool | Status | Case | Note |
|---|---|---|---|
| `ripgrep` | benchmarked | `search-recursive` | ok |
| `ripgrep-all` | benchmarked | `search-docs-ripgrep-all` | ok |
| `fd` | benchmarked | `file-discovery` | ok |
| `fzf` | benchmarked | `fuzzy-filter` | ok |
| `bat` | benchmarked | `file-inspection` | ok |
| `eza` | benchmarked | `tree-listing` | ok |
| `zoxide` | benchmarked | `directory-jump-query` | ok |
| `jq` | benchmarked | `json-query` | ok |
| `yq` | benchmarked | `yaml-query` | ok |
| `simdjson` | skipped | `json-parse-throughput` | missing json2json (simdjson tools) |
| `gron` | benchmarked | `json-flatten` | ok |
| `ast-grep` | benchmarked | `structural-search` | ok |
| `tree-sitter` | skipped | `syntax-parse` | missing tree-sitter |
| `git-delta` | benchmarked | `diff-rendering-delta` | ok |
| `difftastic` | benchmarked | `diff-rendering-difftastic` | ok |
| `sd` | benchmarked | `search-replace` | ok |
| `choose` | skipped | `pipeline-select` | missing choose |
| `hyperfine` | benchmarked | `meta` | used as benchmark runner |
| `httpie` | benchmarked | `http-requests` | ok |
| `xh` | skipped | `http-requests` | missing xh |
| `grpcurl` | skipped | `grpc-url` | requires reproducible grpc server fixture |
| `watchexec` | skipped | `watchexec` | interactive/watch workload not stable in single-shot benchmarks |
| `just` | benchmarked | `task-runner` | ok |
| `procs` | skipped | `process-list` | missing procs |
| `dust` | skipped | `disk-usage` | missing dust |
| `bandwhich` | skipped | `network-process-usage` | requires elevated/network fixture for reproducible results |
| `bottom` | skipped | `system-monitor` | interactive TUI; no stable single-shot benchmark |
