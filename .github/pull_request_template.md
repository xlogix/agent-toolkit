## Summary

Describe what changed and why.

## Changes

- 

## Validation

- [ ] `bash -n install.sh agent-tools.sh scripts/install-agent-tools.sh scripts/release-prep.sh skills/scripts/generate-tool-catalog.sh scripts/benchmarks/run-scientific-benchmarks.sh`
- [ ] `shellcheck install.sh agent-tools.sh scripts/install-agent-tools.sh scripts/release-prep.sh skills/scripts/generate-tool-catalog.sh scripts/benchmarks/run-scientific-benchmarks.sh`
- [ ] `bash skills/scripts/generate-tool-catalog.sh && git diff --exit-code -- skills/references/TOOL-CATALOG.md`
- [ ] Relevant dry-run path tested (for example `./agent-tools.sh install --dry-run`)
- [ ] Docs updated if behavior changed

## Notes

Anything maintainers should know before review.
