# Contributing

Thanks for helping improve `agent-toolkit`.

## Ways To Contribute

- report bugs
- propose features
- improve package-manager support
- improve docs and benchmarks
- improve reliability and DX of CLI flows

## Local Setup

```bash
git clone git@github.com:xlogix/agent-toolkit.git
cd agent-toolkit
chmod +x agent-tools.sh install.sh scripts/install-agent-tools.sh scripts/release-prep.sh
```

## Quick Validation

```bash
bash -n install.sh agent-tools.sh scripts/install-agent-tools.sh scripts/release-prep.sh
shellcheck install.sh agent-tools.sh scripts/install-agent-tools.sh scripts/release-prep.sh
./agent-tools.sh install --package-manager brew --dry-run --no-update
./agent-tools.sh init --repo . --dry-run
```

Use your local package manager if not on Homebrew.

## Pull Request Process

1. Create a branch from `main`.
2. Keep PR scope focused.
3. Include a short "what changed" and "why" summary.
4. Update README/docs if behavior changed.
5. Ensure checks pass.

## Commit Style

Use clear, imperative commit messages:

- `feat: add zypper mapping for yq`
- `fix: keep init gitignore idempotent`
- `docs: add benchmark reproduction section`

## Need Help?

Open a feature request or bug report from the issue templates.
