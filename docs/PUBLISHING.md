# Publishing Guide

This project is a cross-platform installer that orchestrates native package managers. To make it easily available to users, publish in each ecosystem below.

## Release flow (recommended)

Versioning uses **CalVer** tags: `vYYYY.MM.DD` (optional patch: `vYYYY.MM.DD.N`).

1. Tag a release (for example `v2026.03.05`).
2. Publish release artifacts (`install.sh`, `install.ps1`, checksums).
3. Update package manager manifests in `packaging/`.
4. Submit updates to each ecosystem repository.

Helper:

```bash
GITHUB_REPO=<owner>/<repo> ./scripts/release-prep.sh v2026.03.05
```

This prints the SHA256 values to paste into Homebrew and Scoop manifests.

## Homebrew (macOS/Linux)

1. Create a tap repo (for example `homebrew-agent-tools`).
2. Copy `packaging/homebrew/agent-tools.rb` to `Formula/agent-tools.rb`.
3. Update:
   - `url`
   - `sha256`
   - `version`
4. Push and test:
   - `brew tap <owner>/agent-tools`
   - `brew install agent-tools`

## Winget (Windows)

1. Create winget manifests for current version (using Microsoft winget manifest format).
2. Point installer command to your hosted `install.ps1`.
3. Submit PR to `microsoft/winget-pkgs`.
4. Test:
   - `winget install <Your.Package.Id>`

## Scoop (Windows)

1. Host `packaging/scoop/agent-tools.json` in your Scoop bucket.
2. Update:
   - `version`
   - `url`
   - `hash`
3. Users install via:
   - `scoop bucket add <bucket-name> <bucket-url>`
   - `scoop install agent-tools`

## Chocolatey (Windows)

1. Update `packaging/chocolatey/agent-tools.nuspec` and `tools/chocolateyInstall.ps1`.
2. Build package:
   - `choco pack`
3. Push:
   - `choco push agent-tools.<version>.nupkg --source https://push.chocolatey.org/`

## Linux ecosystem tips

For fastest reach, keep script-based install as the universal path, and optionally add native distro packages:

- AUR package (`PKGBUILD`) for Arch.
- COPR for Fedora/RHEL.
- OBS package for openSUSE.
- PPA for Ubuntu (if maintaining .deb packages).

## CI recommendations

- Add smoke tests for `install.sh --dry-run` and `install.ps1 -DryRun`.
- Validate shell syntax (`bash -n`) and PowerShell syntax (`pwsh -NoProfile -Command` parse check).
- Run manager-specific tests in matrix runners where possible.
