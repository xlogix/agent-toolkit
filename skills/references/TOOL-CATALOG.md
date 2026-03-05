# Tool Catalog

This file is generated from `skills/references/tool-list.tsv`.
Do not edit manually. Regenerate with:
`bash skills/scripts/generate-tool-catalog.sh`.

Generated on: 2026-03-05

| Tool | Status | SDLC Stage | Primary Use | Pairs Well With | Notes |
|---|---|---|---|---|---|
| `ripgrep` | default | discovery | Fast recursive text search | fd,fzf | Primary search primitive for large repos |
| `ripgrep-all` | candidate | discovery | Search in PDFs/docs/media text extraction contexts | ripgrep,fd | Useful when non-code artifacts matter |
| `fd` | default | discovery | Fast file discovery and filtering | ripgrep,fzf | Use for path-level narrowing before content search |
| `fzf` | default | discovery | Interactive narrowing of candidate sets | fd,ripgrep | Improves large-set selection speed |
| `bat` | default | validation | Syntax-highlighted file/log inspection | ripgrep,git-delta | Better readability during triage |
| `eza` | default | discovery | Improved directory listing and structure visibility | fd,zoxide | Useful for repo orientation |
| `zoxide` | default | automation | Fast directory jumping across projects | eza,fd | Useful for repeated workspace hops |
| `jq` | default | parsing | JSON query and transform pipelines | httpie,gron | Core structured-data CLI |
| `yq` | default | parsing | YAML/TOML/XML query and edit | jq | Best for config-heavy repositories |
| `simdjson` | candidate | parsing | High-performance JSON parsing | workload-specific | Useful where huge JSON payload performance matters |
| `gron` | candidate | parsing | Flatten JSON into grep-friendly assignments | jq,ripgrep | Great for ad hoc search in nested payloads |
| `ast-grep` | default | refactor | Structural code search and safer refactors | sd,ripgrep | Prefer over regex for syntax-sensitive changes |
| `tree-sitter` | candidate | refactor | Syntax tree tooling and grammar-driven workflows | ast-grep | Best for advanced language-aware analysis |
| `git-delta` | default | review | Readable side-by-side and colorized diffs | difftastic,bat | Default review UX improvement |
| `difftastic` | default | review | Syntax-aware diffing for semantic changes | git-delta | Better signal on complex code diffs |
| `sd` | default | refactor | Modern ergonomic search/replace | ripgrep,ast-grep | Fast textual refactors when AST is unnecessary |
| `choose` | candidate | refactor | Lightweight selector/filter in shell pipelines | ripgrep,fd | Useful for compact pipeline transforms |
| `hyperfine` | default | optimization | Benchmark command variants and loop improvements | ripgrep,fd | Use to validate claimed speedups |
| `httpie` | default | api | Human-friendly HTTP requests and response debugging | jq,grpcurl | Good default for REST workflows |
| `xh` | candidate | api | Fast HTTP client alternative to httpie | jq,grpcurl | Comparable role with different UX/perf profile |
| `grpcurl` | default | api | gRPC endpoint testing and introspection | httpie,jq | Essential for gRPC services |
| `watchexec` | default | automation | Watch-and-rerun loops for rapid feedback | just,procs | Useful in test/build inner loops |
| `just` | default | automation | Task runner for reproducible command recipes | watchexec,zoxide | Organizes common workflows |
| `procs` | candidate | observability | Modern process viewer | ps,bottom | Better process metadata and filtering |
| `dust` | candidate | observability | Disk usage analysis in terminal | eza | Great for footprint/bloat checks |
| `bandwhich` | candidate | observability | Per-process network utilization monitor | procs,bottom | Useful for network-heavy debugging |
| `bottom` | candidate | observability | System monitor for CPU/memory/process visibility | procs,bandwhich | All-in-one TUI monitor |
