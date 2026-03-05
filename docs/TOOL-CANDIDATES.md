# Tool Candidate Matrix

This page tracks additional tool candidates and whether they should be mapped into profile defaults.

Date reviewed: 2026-03-05

## Already Included In Profiles

- `ripgrep`
- `fd`
- `fzf`
- `bat`
- `eza`
- `zoxide`
- `jq`
- `yq`
- `ast-grep`
- `git-delta`
- `difftastic`
- `sd`
- `hyperfine`
- `httpie`
- `grpcurl`
- `watchexec`
- `just`

## Candidate Tools (Requested)

| Tool | Current repo status | Recommendation | Notes |
|---|---|---|---|
| `ripgrep-all` | not mapped | include as optional | confirmed Homebrew formula; verify Linux/Windows package names before adding to profiles |
| `simdjson` | not mapped | include as optional | often packaged as library/tool variants; manager-specific naming differs |
| `gron` | not mapped | include as optional | useful for JSON flattening/search workflows |
| `tree-sitter` | not mapped | include as optional | CLI package naming differs across distros |
| `choose` | not mapped | include as optional | niche but useful in selection pipelines |
| `xh` | not mapped | include as optional | complements `httpie`; avoid default duplication without user demand |
| `procs` | not mapped | include as optional | good process inspection tool |
| `dust` | not mapped | include as optional | useful disk usage explorer |
| `bandwhich` | not mapped | include as optional | network usage visibility; may not be available in every manager |
| `bottom` | not mapped | include as optional | terminal system monitor; manager coverage varies |

## Inclusion Policy

1. Keep profile defaults conservative to preserve lean installs.
2. Add new tools to profile mappings only after explicit package-name mapping is validated for:
   - `brew`, `apt`, `dnf`, `pacman`, `zypper`, `apk`
   - `winget`, `choco`, `scoop` (where applicable)
3. Until full validation, users can install candidates with:

```bash
./agent-tools.sh add <tool-name>
```

## Next Step For Candidate Rollout

Use phased rollout:

1. Add a dedicated opt-in profile (for example, `ops` or `observability`) for candidate tools.
2. Validate per-manager package names with dry-run tests.
3. Promote high-signal tools into existing profiles only after stability is confirmed.
