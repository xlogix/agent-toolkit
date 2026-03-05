#!/usr/bin/env bash

set -u
set -o pipefail

WITH_EXTRAS=0
DRY_RUN=0
NO_UPDATE=0
STRICT=0
PACKAGE_MANAGER=""
PROFILES_RAW=""
USER_SET_PROFILES=0
ADD_RAW=""
REMOVE_RAW=""

INSTALLED=()
SKIPPED=()
FAILED=()
TARGET_PROFILES=()
TARGET_PACKAGES=()

usage() {
  cat <<'EOF'
Usage: ./install.sh [options]

Installs a toolkit for coding agents on macOS/Linux.

Options:
  --profiles <csv>           Comma-separated packs: core,ui,api,infra,quality,all
  --extras                   Shortcut: add ui,api,infra,quality packs
  --add <csv-or-name>        Add package(s) manually (repeatable)
  --remove <csv-or-name>     Remove package(s) from selected set (repeatable)
  --package-manager <name>   Force package manager: brew|apt|dnf|pacman|zypper|apk
  --no-update                Skip package index refresh step
  --dry-run                  Print commands without executing
  --strict                   Exit non-zero if any package fails
  -h, --help                 Show help

Examples:
  ./install.sh
  ./install.sh --profiles core
  ./install.sh --profiles core,ui,api
  ./install.sh --profiles core --add httpie --add grpcurl
  ./install.sh --profiles core,quality --remove lazygit
  ./install.sh --extras
EOF
}

log() { printf '%s\n' "$*"; }
warn() { printf 'Warning: %s\n' "$*" >&2; }
err() { printf 'Error: %s\n' "$*" >&2; }

run_cmd() {
  if [[ "$DRY_RUN" -eq 1 ]]; then
    printf '[dry-run] '
    printf '%q ' "$@"
    printf '\n'
    return 0
  fi
  "$@"
}

append_unique_profile() {
  local value="$1"
  local existing
  for existing in "${TARGET_PROFILES[@]:-}"; do
    [[ "$existing" == "$value" ]] && return 0
  done
  TARGET_PROFILES+=("$value")
}

append_unique_package() {
  local value="$1"
  local existing
  for existing in "${TARGET_PACKAGES[@]:-}"; do
    [[ "$existing" == "$value" ]] && return 0
  done
  TARGET_PACKAGES+=("$value")
}

tokenize_csv() {
  local raw="$1"
  echo "$raw" | tr ',' ' '
}

parse_tokens_into_profiles() {
  local raw="$1"
  local token
  for token in $(tokenize_csv "$raw"); do
    [[ -n "$token" ]] && expand_profile_token "$token"
  done
}

parse_tokens_into_raw_list() {
  local raw="$1"
  local token
  for token in $(tokenize_csv "$raw"); do
    [[ -n "$token" ]] && printf '%s\n' "$token"
  done
}

is_supported_profile() {
  case "$1" in
    core|ui|api|infra|quality|all) return 0 ;;
    *) return 1 ;;
  esac
}

expand_profile_token() {
  local token="$1"
  case "$token" in
    all)
      append_unique_profile "core"
      append_unique_profile "ui"
      append_unique_profile "api"
      append_unique_profile "infra"
      append_unique_profile "quality"
      ;;
    *)
      append_unique_profile "$token"
      ;;
  esac
}

detect_package_manager() {
  if [[ -n "$PACKAGE_MANAGER" ]]; then
    return
  fi
  if command -v brew >/dev/null 2>&1; then
    PACKAGE_MANAGER="brew"
  elif command -v apt-get >/dev/null 2>&1; then
    PACKAGE_MANAGER="apt"
  elif command -v dnf >/dev/null 2>&1; then
    PACKAGE_MANAGER="dnf"
  elif command -v pacman >/dev/null 2>&1; then
    PACKAGE_MANAGER="pacman"
  elif command -v zypper >/dev/null 2>&1; then
    PACKAGE_MANAGER="zypper"
  elif command -v apk >/dev/null 2>&1; then
    PACKAGE_MANAGER="apk"
  fi
}

is_supported_manager() {
  case "$1" in
    brew|apt|dnf|pacman|zypper|apk) return 0 ;;
    *) return 1 ;;
  esac
}

profile_packages_for() {
  local manager="$1"
  local profile="$2"
  case "$profile" in
    core)
      case "$manager" in
        brew) echo "ripgrep fd jq yq fzf bat eza git-delta" ;;
        apt) echo "ripgrep fd-find jq yq fzf bat eza git-delta" ;;
        dnf) echo "ripgrep fd-find jq yq fzf bat eza git-delta" ;;
        pacman) echo "ripgrep fd jq yq fzf bat eza git-delta" ;;
        zypper) echo "ripgrep fd jq yq fzf bat eza git-delta" ;;
        apk) echo "ripgrep fd jq yq fzf bat eza git-delta" ;;
      esac
      ;;
    ui)
      case "$manager" in
        brew) echo "imagemagick ffmpeg tesseract" ;;
        apt) echo "imagemagick ffmpeg tesseract-ocr" ;;
        dnf) echo "ImageMagick ffmpeg tesseract" ;;
        pacman) echo "imagemagick ffmpeg tesseract" ;;
        zypper) echo "ImageMagick ffmpeg tesseract-ocr" ;;
        apk) echo "imagemagick ffmpeg tesseract-ocr" ;;
      esac
      ;;
    api)
      case "$manager" in
        brew) echo "gh httpie grpcurl" ;;
        apt) echo "gh httpie grpcurl" ;;
        dnf) echo "gh httpie grpcurl" ;;
        pacman) echo "github-cli httpie grpcurl" ;;
        zypper) echo "gh httpie grpcurl" ;;
        apk) echo "gh httpie grpcurl" ;;
      esac
      ;;
    infra)
      case "$manager" in
        brew) echo "just direnv zoxide watchexec" ;;
        apt) echo "just direnv zoxide watchexec" ;;
        dnf) echo "just direnv zoxide watchexec" ;;
        pacman) echo "just direnv zoxide watchexec" ;;
        zypper) echo "just direnv zoxide watchexec" ;;
        apk) echo "just direnv zoxide watchexec" ;;
      esac
      ;;
    quality)
      case "$manager" in
        brew) echo "shellcheck hyperfine ast-grep sd difftastic lazygit" ;;
        apt) echo "shellcheck hyperfine ast-grep sd difftastic lazygit" ;;
        dnf) echo "ShellCheck hyperfine ast-grep sd difftastic lazygit" ;;
        pacman) echo "shellcheck hyperfine ast-grep sd difftastic lazygit" ;;
        zypper) echo "shellcheck hyperfine ast-grep sd difftastic lazygit" ;;
        apk) echo "shellcheck hyperfine ast-grep sd difftastic lazygit" ;;
      esac
      ;;
  esac
}

resolve_profiles() {
  TARGET_PROFILES=()
  if [[ "$USER_SET_PROFILES" -eq 1 && -n "$PROFILES_RAW" ]]; then
    parse_tokens_into_profiles "$PROFILES_RAW"
  else
    append_unique_profile "core"
    append_unique_profile "ui"
    append_unique_profile "api"
    append_unique_profile "infra"
    append_unique_profile "quality"
  fi

  if [[ "$WITH_EXTRAS" -eq 1 ]]; then
    append_unique_profile "ui"
    append_unique_profile "api"
    append_unique_profile "infra"
    append_unique_profile "quality"
  fi

  if [[ ${#TARGET_PROFILES[@]} -eq 0 ]]; then
    append_unique_profile "core"
    append_unique_profile "ui"
    append_unique_profile "api"
    append_unique_profile "infra"
    append_unique_profile "quality"
  fi

  local profile
  for profile in "${TARGET_PROFILES[@]}"; do
    if ! is_supported_profile "$profile"; then
      err "Unsupported profile: $profile (allowed: core,ui,api,infra,quality,all)"
      exit 1
    fi
  done
}

resolve_target_packages() {
  TARGET_PACKAGES=()

  local profile pkg remove_item should_remove
  local profile_pkgs=()

  for profile in "${TARGET_PROFILES[@]}"; do
    read -r -a profile_pkgs <<< "$(profile_packages_for "$PACKAGE_MANAGER" "$profile")"
    for pkg in "${profile_pkgs[@]}"; do
      append_unique_package "$pkg"
    done
  done

  for pkg in $(parse_tokens_into_raw_list "$ADD_RAW"); do
    append_unique_package "$pkg"
  done

  if [[ -n "$REMOVE_RAW" ]]; then
    local filtered=()
    for pkg in "${TARGET_PACKAGES[@]}"; do
      should_remove=0
      for remove_item in $(parse_tokens_into_raw_list "$REMOVE_RAW"); do
        if [[ "$pkg" == "$remove_item" ]]; then
          should_remove=1
          break
        fi
      done
      if [[ "$should_remove" -eq 0 ]]; then
        filtered+=("$pkg")
      fi
    done
    TARGET_PACKAGES=("${filtered[@]}")
  fi
}

SUDO=()
if [[ "${EUID:-$(id -u)}" -ne 0 ]] && command -v sudo >/dev/null 2>&1; then
  SUDO=(sudo)
fi

prepare_manager() {
  if [[ "$NO_UPDATE" -eq 1 ]]; then
    log "==> Skipping package index refresh (--no-update)"
    return
  fi

  log "==> Refreshing package index for $PACKAGE_MANAGER..."
  case "$PACKAGE_MANAGER" in
    brew) run_cmd brew update ;;
    apt) run_cmd "${SUDO[@]}" apt-get update ;;
    dnf) run_cmd "${SUDO[@]}" dnf makecache ;;
    pacman) run_cmd "${SUDO[@]}" pacman -Sy --noconfirm ;;
    zypper) run_cmd "${SUDO[@]}" zypper --non-interactive refresh ;;
    apk) run_cmd "${SUDO[@]}" apk update ;;
  esac
}

is_installed() {
  local pkg="$1"
  case "$PACKAGE_MANAGER" in
    brew) brew list --versions "$pkg" >/dev/null 2>&1 ;;
    apt) dpkg -s "$pkg" >/dev/null 2>&1 ;;
    dnf) dnf list installed "$pkg" >/dev/null 2>&1 ;;
    pacman) pacman -Qi "$pkg" >/dev/null 2>&1 ;;
    zypper) zypper --quiet search --installed-only --match-exact "$pkg" >/dev/null 2>&1 ;;
    apk) apk info -e "$pkg" >/dev/null 2>&1 ;;
    *) return 1 ;;
  esac
}

install_package() {
  local pkg="$1"
  case "$PACKAGE_MANAGER" in
    brew) run_cmd brew install "$pkg" ;;
    apt) run_cmd "${SUDO[@]}" apt-get install -y "$pkg" ;;
    dnf) run_cmd "${SUDO[@]}" dnf install -y "$pkg" ;;
    pacman) run_cmd "${SUDO[@]}" pacman -S --noconfirm --needed "$pkg" ;;
    zypper) run_cmd "${SUDO[@]}" zypper --non-interactive install --no-confirm "$pkg" ;;
    apk) run_cmd "${SUDO[@]}" apk add --no-cache "$pkg" ;;
    *) return 1 ;;
  esac
}

install_list() {
  local group="$1"
  shift
  local pkg

  [[ $# -eq 0 ]] && return 0
  log "==> Installing $group tools..."

  for pkg in "$@"; do
    if is_installed "$pkg"; then
      log "  - $pkg (already installed)"
      SKIPPED+=("$pkg")
      continue
    fi

    log "  - $pkg"
    if install_package "$pkg"; then
      INSTALLED+=("$pkg")
    else
      warn "Failed to install package '$pkg' on manager '$PACKAGE_MANAGER'"
      FAILED+=("$pkg")
    fi
  done
}

print_post_install_notes() {
  log
  log "==> Notes"

  if [[ "$PACKAGE_MANAGER" == "apt" ]]; then
    if command -v fdfind >/dev/null 2>&1 && ! command -v fd >/dev/null 2>&1; then
      log "  - Debian/Ubuntu exposes fd as 'fdfind'. Add alias: alias fd=fdfind"
    fi
    if command -v batcat >/dev/null 2>&1 && ! command -v bat >/dev/null 2>&1; then
      log "  - Debian/Ubuntu exposes bat as 'batcat'. Add alias: alias bat=batcat"
    fi
  fi

  if [[ "$PACKAGE_MANAGER" == "brew" ]]; then
    local ffmpeg_bin=""
    ffmpeg_bin="$(command -v ffmpeg || true)"
    if [[ "$ffmpeg_bin" == *"ffmpeg@6"* ]]; then
      log "  - ffmpeg resolves to $ffmpeg_bin (legacy). Prefer /opt/homebrew/bin/ffmpeg"
    fi
  fi

  log "  - Lean mode tip: keep only needed packs with --profiles and trim with --remove."
}

print_summary() {
  log
  log "==> Summary"
  log "  Package manager: $PACKAGE_MANAGER"
  log "  Profiles: ${TARGET_PROFILES[*]}"
  log "  Installed: ${#INSTALLED[@]}"
  log "  Already present: ${#SKIPPED[@]}"
  log "  Failed: ${#FAILED[@]}"

  if [[ -n "$ADD_RAW" ]]; then
    log "  Manual add: $(parse_tokens_into_raw_list "$ADD_RAW" | tr '\n' ' ' | sed 's/ *$//')"
  fi
  if [[ -n "$REMOVE_RAW" ]]; then
    log "  Manual remove: $(parse_tokens_into_raw_list "$REMOVE_RAW" | tr '\n' ' ' | sed 's/ *$//')"
  fi

  if [[ ${#FAILED[@]} -gt 0 ]]; then
    log "  Failed packages: ${FAILED[*]}"
    log "  Tip: rerun with --dry-run to inspect commands, or switch manager with --package-manager."
  fi
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --profiles)
      shift
      if [[ $# -eq 0 ]]; then
        err "--profiles requires a value"
        usage
        exit 1
      fi
      PROFILES_RAW="$1"
      USER_SET_PROFILES=1
      ;;
    --extras) WITH_EXTRAS=1 ;;
    --add)
      shift
      if [[ $# -eq 0 ]]; then
        err "--add requires a value"
        usage
        exit 1
      fi
      ADD_RAW="$ADD_RAW $(tokenize_csv "$1")"
      ;;
    --remove)
      shift
      if [[ $# -eq 0 ]]; then
        err "--remove requires a value"
        usage
        exit 1
      fi
      REMOVE_RAW="$REMOVE_RAW $(tokenize_csv "$1")"
      ;;
    --dry-run) DRY_RUN=1 ;;
    --no-update) NO_UPDATE=1 ;;
    --strict) STRICT=1 ;;
    --package-manager)
      shift
      if [[ $# -eq 0 ]]; then
        err "--package-manager requires a value"
        usage
        exit 1
      fi
      PACKAGE_MANAGER="$1"
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      err "Unknown argument: $1"
      usage
      exit 1
      ;;
  esac
  shift
done

detect_package_manager
if [[ -z "$PACKAGE_MANAGER" ]]; then
  err "Could not detect a supported package manager. Supported: brew/apt/dnf/pacman/zypper/apk."
  exit 1
fi

if ! is_supported_manager "$PACKAGE_MANAGER"; then
  err "Unsupported package manager: $PACKAGE_MANAGER"
  exit 1
fi

resolve_profiles
resolve_target_packages

if [[ ${#TARGET_PACKAGES[@]} -eq 0 ]]; then
  warn "No packages selected after applying profiles and remove filters."
  exit 0
fi

log "==> Using package manager: $PACKAGE_MANAGER"
prepare_manager
install_list "selected" "${TARGET_PACKAGES[@]}"
print_summary
print_post_install_notes

if [[ "$STRICT" -eq 1 && ${#FAILED[@]} -gt 0 ]]; then
  exit 1
fi

exit 0
