#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
CATALOG_SCRIPT="$ROOT_DIR/skills/scripts/generate-tool-catalog.sh"
CATALOG_FILE="$ROOT_DIR/skills/references/TOOL-CATALOG.md"

if [[ $# -lt 1 ]]; then
  echo "Usage: GITHUB_REPO=<owner>/<repo> ./scripts/release-prep.sh <version>"
  echo "Example: GITHUB_REPO=myorg/agent-tools ./scripts/release-prep.sh v2026.03.05"
  echo "Version format: vYYYY.MM.DD (optional: vYYYY.MM.DD.N)"
  exit 1
fi

if [[ -z "${GITHUB_REPO:-}" ]]; then
  echo "Error: GITHUB_REPO must be set to <owner>/<repo>"
  exit 1
fi

VERSION="$1"
if ! [[ "$VERSION" =~ ^v[0-9]{4}\.[0-9]{2}\.[0-9]{2}(\.[0-9]+)?$ ]]; then
  echo "Error: version must match CalVer tag format vYYYY.MM.DD or vYYYY.MM.DD.N"
  exit 1
fi

if [[ -x "$CATALOG_SCRIPT" ]]; then
  echo "==> Verifying generated tool catalog is up to date"
  bash "$CATALOG_SCRIPT" >/dev/null
  if command -v git >/dev/null 2>&1 && git -C "$ROOT_DIR" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    if ! git -C "$ROOT_DIR" diff --quiet -- "$CATALOG_FILE"; then
      echo "Error: $CATALOG_FILE is stale. Regenerate and commit before release."
      git -C "$ROOT_DIR" --no-pager diff -- "$CATALOG_FILE" || true
      exit 1
    fi
  fi
fi

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

BASE_URL="https://github.com/${GITHUB_REPO}/archive/refs/tags/${VERSION}"
TGZ_PATH="$TMP_DIR/release.tar.gz"
ZIP_PATH="$TMP_DIR/release.zip"

echo "==> Downloading release assets for ${GITHUB_REPO}@${VERSION}"
curl -fsSL "${BASE_URL}.tar.gz" -o "$TGZ_PATH"
curl -fsSL "${BASE_URL}.zip" -o "$ZIP_PATH"

TGZ_SHA="$(shasum -a 256 "$TGZ_PATH" | awk '{print $1}')"
ZIP_SHA="$(shasum -a 256 "$ZIP_PATH" | awk '{print $1}')"

cat <<EOF
==> Checksums
Homebrew tar.gz SHA256: $TGZ_SHA
Scoop zip SHA256:       $ZIP_SHA

==> Update these files
- packaging/homebrew/agent-tools.rb
  url: https://github.com/${GITHUB_REPO}/archive/refs/tags/${VERSION}.tar.gz
  sha256: $TGZ_SHA

- packaging/scoop/agent-tools.json
  version: ${VERSION#v}
  url: https://github.com/${GITHUB_REPO}/archive/refs/tags/${VERSION}.zip
  hash: $ZIP_SHA
EOF
