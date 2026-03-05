# AGENTS.md

This file helps both human contributors and coding agents collaborate safely in this repo.

## Mission

`agent-toolkit` provides a cross-platform CLI toolkit that makes coding-agent workflows faster:

- install
- update
- reinstall
- diagnose
- initialize repo-safe `.gitignore` entries

## Start Here

1. Read [README.md](./README.md).
2. Run the CLI help:
   - `./agent-tools.sh --help`
3. Run checks before opening a PR:
   - `bash -n install.sh agent-tools.sh scripts/install-agent-tools.sh scripts/release-prep.sh`
   - `shellcheck install.sh agent-tools.sh scripts/install-agent-tools.sh scripts/release-prep.sh`
   - `./agent-tools.sh install --package-manager brew --dry-run --no-update` (or your local manager)

## Contributor Rules

1. Keep scripts cross-platform and shell-safe.
2. Prefer additive changes over breaking existing commands.
3. Keep package mappings explicit per package manager.
4. If behavior changes, update docs in the same PR.
5. Do not commit secrets, tokens, or machine-local paths.

## Agent-Specific Guidance

When changing installer logic:

1. Validate `install`, `update`, `reinstall`, `add`, `doctor`, and `init` paths.
2. Preserve idempotency where expected (especially `init` for `.gitignore`).
3. Keep dry-run support accurate and predictable.
4. Prefer clear failure summaries instead of hard-failing early.

## Definition Of Done

A contribution is ready when:

1. Scripts pass syntax and lint checks.
2. Dry-run works for the modified path.
3. README/docs are updated.
4. PR explains what changed and why.

