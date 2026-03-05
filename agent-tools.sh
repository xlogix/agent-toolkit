#!/usr/bin/env bash

set -u
set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_SCRIPT="$SCRIPT_DIR/install.sh"

PACKAGE_MANAGER=""
WITH_EXTRAS=0
NO_UPDATE=0
STRICT=0
DRY_RUN=0
PROFILES_RAW=""
USER_SET_PROFILES=0
ADD_RAW=""
REMOVE_RAW=""

TARGET_PROFILES=()
TARGET_PACKAGES=()

SUDO=()
if [[ "${EUID:-$(id -u)}" -ne 0 ]] && command -v sudo >/dev/null 2>&1; then
  SUDO=(sudo)
fi

usage() {
  cat <<'EOF'
Usage:
  ./agent-tools.sh menu
  ./agent-tools.sh install [--profiles <csv>] [--extras] [--add <pkg>] [--remove <pkg>] [--package-manager <name>] [--no-update] [--dry-run] [--strict]
  ./agent-tools.sh update [--profiles <csv>] [--extras] [--add <pkg>] [--remove <pkg>] [--package-manager <name>] [--no-update] [--dry-run] [--strict]
  ./agent-tools.sh reinstall [--profiles <csv>] [--extras] [--add <pkg>] [--remove <pkg>] [--package-manager <name>] [--no-update] [--dry-run] [--strict]
  ./agent-tools.sh profiles [--package-manager <name>]
  ./agent-tools.sh add <package...> [--package-manager <name>] [--dry-run] [--strict]
  ./agent-tools.sh doctor [--package-manager <name>] [--dry-run]
  ./agent-tools.sh init [--repo <path>] [--dry-run]
  ./agent-tools.sh --help

Profiles:
  core, ui, api, infra, quality, all

Notes:
  - If --profiles is omitted, all packs are selected.
  - Use --profiles core for lean/minimal installs.
  - --extras adds ui,api,infra,quality on top of selected profiles.
  - Use --add/--remove to customize final package selection.

Examples:
  ./agent-tools.sh install
  ./agent-tools.sh install --profiles core
  ./agent-tools.sh install --profiles core,ui,api --remove tesseract
  ./agent-tools.sh install --profiles core --add httpie --add grpcurl
  ./agent-tools.sh profiles
  ./agent-tools.sh init
  ./agent-tools.sh init --repo /path/to/repo
EOF
}

log() { printf '%s\n' "$*"; }
warn() { printf 'Warning: %s\n' "$*" >&2; }
err() { printf 'Error: %s\n' "$*" >&2; }

UI_ENABLE=0
CLR_RESET=""
CLR_BOLD=""
CLR_CYAN=""
CLR_GREEN=""
CLR_YELLOW=""
CLR_DIM=""

init_ui() {
  if [[ -t 1 ]] && command -v tput >/dev/null 2>&1; then
    UI_ENABLE=1
    CLR_RESET="$(tput sgr0 || true)"
    CLR_BOLD="$(tput bold || true)"
    CLR_CYAN="$(tput setaf 6 || true)"
    CLR_GREEN="$(tput setaf 2 || true)"
    CLR_YELLOW="$(tput setaf 3 || true)"
    CLR_DIM="$(tput dim || true)"
  fi
}

run_cmd() {
  if [[ "$DRY_RUN" -eq 1 ]]; then
    printf '[dry-run] '
    printf '%q ' "$@"
    printf '\n'
    return 0
  fi
  "$@"
}

tokenize_csv() {
  local raw="$1"
  echo "$raw" | tr ',' ' '
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

ensure_supported_manager() {
  case "$PACKAGE_MANAGER" in
    brew|apt|dnf|pacman|zypper|apk) return 0 ;;
    *)
      err "Unsupported package manager: $PACKAGE_MANAGER"
      return 1
      ;;
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

resolve_selected_packages() {
  local manager="$1"
  TARGET_PACKAGES=()

  local profile pkg remove_item should_remove
  local profile_pkgs=()

  resolve_profiles

  for profile in "${TARGET_PROFILES[@]}"; do
    read -r -a profile_pkgs <<< "$(profile_packages_for "$manager" "$profile")"
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

show_profiles() {
  local manager="$1"
  local profile
  local profile_pkgs=()

  log "==> Profiles for package manager: $manager"
  for profile in core ui api infra quality; do
    read -r -a profile_pkgs <<< "$(profile_packages_for "$manager" "$profile")"
    log "[$profile] ${profile_pkgs[*]}"
  done
  log
  log "Examples:"
  log "  ./agent-tools.sh install --profiles core,ui,api"
  log "  ./agent-tools.sh install --profiles all"
  log "  ./agent-tools.sh install --profiles core --add httpie --remove fzf"
}

current_profile_summary() {
  if [[ "$USER_SET_PROFILES" -eq 1 && -n "$PROFILES_RAW" ]]; then
    echo "$PROFILES_RAW"
  else
    echo "all (default)"
  fi
}

render_menu_screen() {
  local manager_display="auto-detect"
  local profiles_display add_display remove_display
  profiles_display="$(current_profile_summary)"
  add_display="${ADD_RAW:-none}"
  remove_display="${REMOVE_RAW:-none}"

  detect_package_manager || true
  if [[ -n "$PACKAGE_MANAGER" ]]; then
    manager_display="$PACKAGE_MANAGER"
  fi

  if [[ "$UI_ENABLE" -eq 1 ]]; then
    clear
    printf '%s%s' "$CLR_CYAN" "$CLR_BOLD"
    cat <<'EOF'
    ___                    __   ______            __   _ __
   /   | ____ ____  ____  / /_ /_  __/___  ____  / /__(_) /_
  / /| |/ __ `/ _ \/ __ \/ __/  / / / __ \/ __ \/ //_/ / __/
 / ___ / /_/ /  __/ / / / /_   / / / /_/ / /_/ / ,< / / /_
/_/  |_\__, /\___/_/ /_/\__/  /_/  \____/\____/_/|_/_/\__/
      /____/
EOF
    printf '%s\n' "$CLR_RESET"
    printf '%sAgentTools Assemble%s\n' "$CLR_GREEN" "$CLR_RESET"
    printf '%sLean + Modular CLI for coding-agent tooling%s\n\n' "$CLR_DIM" "$CLR_RESET"
    printf '%sEnvironment%s\n' "$CLR_BOLD$CLR_CYAN" "$CLR_RESET"
    printf '  Manager : %s\n' "$manager_display"
    printf '  Profiles: %s\n' "$profiles_display"
    printf '  Add     : %s\n' "$add_display"
    printf '  Remove  : %s\n' "$remove_display"
    printf '\n%sActions%s\n' "$CLR_BOLD$CLR_CYAN" "$CLR_RESET"
    printf '  %s1%s  Install lean core\n' "$CLR_GREEN" "$CLR_RESET"
    printf '  %s2%s  Install full packs (core+ui+api+infra+quality)\n' "$CLR_GREEN" "$CLR_RESET"
    printf '  %s3%s  Update selected packs\n' "$CLR_GREEN" "$CLR_RESET"
    printf '  %s4%s  Reinstall selected packs\n' "$CLR_GREEN" "$CLR_RESET"
    printf '  %s5%s  Install custom package names\n' "$CLR_GREEN" "$CLR_RESET"
    printf '  %s6%s  Run diagnostics / fix suggestions\n' "$CLR_GREEN" "$CLR_RESET"
    printf '  %s7%s  Add local temp files to .gitignore\n' "$CLR_GREEN" "$CLR_RESET"
    printf '  %s8%s  List profile packs and tools\n' "$CLR_GREEN" "$CLR_RESET"
    printf '  %s9%s  Exit\n\n' "$CLR_GREEN" "$CLR_RESET"
  else
    cat <<EOF

Agent Tools Menu
Manager : $manager_display
Profiles: $profiles_display
Add     : $add_display
Remove  : $remove_display

1) Install lean core
2) Install full packs (core+ui+api+infra+quality)
3) Update selected packs
4) Reinstall selected packs
5) Install custom package names
6) Run diagnostics / fix suggestions
7) Add local temp files to .gitignore
8) List profile packs and tools
9) Exit

EOF
  fi
}

prepare_manager_for_updates() {
  if [[ "$NO_UPDATE" -eq 1 ]]; then
    log "==> Skipping package index refresh (--no-update)"
    return
  fi
  case "$PACKAGE_MANAGER" in
    brew) run_cmd brew update ;;
    apt) run_cmd "${SUDO[@]}" apt-get update ;;
    dnf) run_cmd "${SUDO[@]}" dnf makecache ;;
    pacman) run_cmd "${SUDO[@]}" pacman -Sy --noconfirm ;;
    zypper) run_cmd "${SUDO[@]}" zypper --non-interactive refresh ;;
    apk) run_cmd "${SUDO[@]}" apk update ;;
  esac
}

update_packages() {
  local packages=("$@")
  local failed=()
  local pkg

  [[ ${#packages[@]} -eq 0 ]] && { warn "No packages selected to update."; return 0; }
  log "==> Updating selected packages on $PACKAGE_MANAGER..."
  prepare_manager_for_updates

  case "$PACKAGE_MANAGER" in
    brew)
      for pkg in "${packages[@]}"; do
        if ! run_cmd brew upgrade "$pkg"; then failed+=("$pkg"); fi
      done
      ;;
    apt)
      for pkg in "${packages[@]}"; do
        if ! run_cmd "${SUDO[@]}" apt-get install --only-upgrade -y "$pkg"; then failed+=("$pkg"); fi
      done
      ;;
    dnf)
      for pkg in "${packages[@]}"; do
        if ! run_cmd "${SUDO[@]}" dnf upgrade -y "$pkg"; then failed+=("$pkg"); fi
      done
      ;;
    pacman)
      for pkg in "${packages[@]}"; do
        if ! run_cmd "${SUDO[@]}" pacman -S --noconfirm "$pkg"; then failed+=("$pkg"); fi
      done
      ;;
    zypper)
      for pkg in "${packages[@]}"; do
        if ! run_cmd "${SUDO[@]}" zypper --non-interactive update "$pkg"; then failed+=("$pkg"); fi
      done
      ;;
    apk)
      for pkg in "${packages[@]}"; do
        if ! run_cmd "${SUDO[@]}" apk upgrade "$pkg"; then failed+=("$pkg"); fi
      done
      ;;
  esac

  if [[ ${#failed[@]} -gt 0 ]]; then
    warn "Update failures: ${failed[*]}"
    [[ "$STRICT" -eq 1 ]] && return 1
  fi
}

reinstall_packages() {
  local packages=("$@")
  local failed=()
  local pkg

  [[ ${#packages[@]} -eq 0 ]] && { warn "No packages selected to reinstall."; return 0; }
  log "==> Reinstalling selected packages on $PACKAGE_MANAGER..."
  prepare_manager_for_updates

  case "$PACKAGE_MANAGER" in
    brew)
      for pkg in "${packages[@]}"; do
        if ! run_cmd brew reinstall "$pkg"; then failed+=("$pkg"); fi
      done
      ;;
    apt)
      for pkg in "${packages[@]}"; do
        if ! run_cmd "${SUDO[@]}" apt-get install --reinstall -y "$pkg"; then failed+=("$pkg"); fi
      done
      ;;
    dnf)
      for pkg in "${packages[@]}"; do
        if ! run_cmd "${SUDO[@]}" dnf reinstall -y "$pkg"; then failed+=("$pkg"); fi
      done
      ;;
    pacman)
      for pkg in "${packages[@]}"; do
        if ! run_cmd "${SUDO[@]}" pacman -S --noconfirm "$pkg"; then failed+=("$pkg"); fi
      done
      ;;
    zypper)
      for pkg in "${packages[@]}"; do
        if ! run_cmd "${SUDO[@]}" zypper --non-interactive install --force "$pkg"; then failed+=("$pkg"); fi
      done
      ;;
    apk)
      for pkg in "${packages[@]}"; do
        if ! run_cmd "${SUDO[@]}" apk fix "$pkg"; then failed+=("$pkg"); fi
      done
      ;;
  esac

  if [[ ${#failed[@]} -gt 0 ]]; then
    warn "Reinstall failures: ${failed[*]}"
    [[ "$STRICT" -eq 1 ]] && return 1
  fi
}

add_packages() {
  local packages=("$@")
  local failed=()
  local pkg

  [[ ${#packages[@]} -eq 0 ]] && { err "No packages provided to add."; return 1; }
  log "==> Installing custom packages on $PACKAGE_MANAGER..."
  prepare_manager_for_updates

  case "$PACKAGE_MANAGER" in
    brew)
      for pkg in "${packages[@]}"; do
        if ! run_cmd brew install "$pkg"; then failed+=("$pkg"); fi
      done
      ;;
    apt)
      for pkg in "${packages[@]}"; do
        if ! run_cmd "${SUDO[@]}" apt-get install -y "$pkg"; then failed+=("$pkg"); fi
      done
      ;;
    dnf)
      for pkg in "${packages[@]}"; do
        if ! run_cmd "${SUDO[@]}" dnf install -y "$pkg"; then failed+=("$pkg"); fi
      done
      ;;
    pacman)
      for pkg in "${packages[@]}"; do
        if ! run_cmd "${SUDO[@]}" pacman -S --noconfirm "$pkg"; then failed+=("$pkg"); fi
      done
      ;;
    zypper)
      for pkg in "${packages[@]}"; do
        if ! run_cmd "${SUDO[@]}" zypper --non-interactive install "$pkg"; then failed+=("$pkg"); fi
      done
      ;;
    apk)
      for pkg in "${packages[@]}"; do
        if ! run_cmd "${SUDO[@]}" apk add --no-cache "$pkg"; then failed+=("$pkg"); fi
      done
      ;;
  esac

  if [[ ${#failed[@]} -gt 0 ]]; then
    warn "Install failures: ${failed[*]}"
    [[ "$STRICT" -eq 1 ]] && return 1
  fi
}

doctor() {
  local manager="$1"
  local expected_bins=(rg jq yq fzf bat eza delta)
  local missing_bins=()
  local b

  case "$manager" in
    apt) expected_bins+=(fdfind) ;;
    *) expected_bins+=(fd) ;;
  esac

  log "==> Running diagnostics..."
  log "Package manager: $manager"

  for b in "${expected_bins[@]}"; do
    if ! command -v "$b" >/dev/null 2>&1; then
      missing_bins+=("$b")
    fi
  done

  if [[ ${#missing_bins[@]} -eq 0 ]]; then
    log "All expected core binaries found in PATH."
  else
    warn "Missing core binaries: ${missing_bins[*]}"
    log "Suggested fix: ./agent-tools.sh reinstall --profiles core --package-manager $manager"
  fi

  if [[ "$manager" == "brew" ]]; then
    local ffmpeg_bin
    ffmpeg_bin="$(command -v ffmpeg || true)"
    if [[ "$ffmpeg_bin" == *"ffmpeg@6"* ]]; then
      warn "Legacy ffmpeg@6 path detected: $ffmpeg_bin"
      log "Fix: use /opt/homebrew/bin/ffmpeg or remove ffmpeg@6 from PATH."
    fi
    log "Running brew doctor..."
    run_cmd brew doctor || true
  fi

  if [[ "$manager" == "apt" ]]; then
    if command -v fdfind >/dev/null 2>&1 && ! command -v fd >/dev/null 2>&1; then
      log "Tip: add alias fd=fdfind"
    fi
    if command -v batcat >/dev/null 2>&1 && ! command -v bat >/dev/null 2>&1; then
      log "Tip: add alias bat=batcat"
    fi
  fi
}

append_if_missing() {
  local file="$1"
  local line="$2"
  grep -Fqx "$line" "$file" 2>/dev/null || printf '%s\n' "$line" >> "$file"
}

resolve_repo_root() {
  local requested="${1:-}"
  if [[ -n "$requested" ]]; then
    (cd "$requested" >/dev/null 2>&1 && pwd) || return 1
    return 0
  fi
  git rev-parse --show-toplevel 2>/dev/null || pwd
}

init_repo_gitignore() {
  local target_repo="$1"
  local gitignore="$target_repo/.gitignore"

  if [[ ! -f "$gitignore" ]]; then
    if [[ "$DRY_RUN" -eq 1 ]]; then
      log "[dry-run] touch $gitignore"
    else
      touch "$gitignore"
    fi
  fi

  local lines=(
    "# Temporary working files (generated locally)"
    "tmp/"
    ".generated/"
    "# AI Agents"
    ".claude/"
    ".playwright-cli/"
    "# Test and debug artifacts"
    "coverage/"
    "test-results/"
    "artifacts/"
    "*.log"
  )

  log "==> Patching .gitignore in: $target_repo"
  log "Includes: tmp/, .generated/, .claude/, .playwright-cli/, coverage/, test-results/, artifacts/, *.log"
  if [[ "$DRY_RUN" -eq 1 ]]; then
    local l
    for l in "${lines[@]}"; do
      if [[ -n "$l" ]] && ! grep -Fqx "$l" "$gitignore" 2>/dev/null; then
        log "[dry-run] add: $l"
      fi
    done
    return 0
  fi

  local l
  for l in "${lines[@]}"; do
    append_if_missing "$gitignore" "$l"
  done

  log "Updated: $gitignore"
}

run_install() {
  local args=()
  [[ "$WITH_EXTRAS" -eq 1 ]] && args+=(--extras)
  [[ "$USER_SET_PROFILES" -eq 1 ]] && args+=(--profiles "$PROFILES_RAW")
  if [[ -n "$ADD_RAW" ]]; then
    for token in $(parse_tokens_into_raw_list "$ADD_RAW"); do
      args+=(--add "$token")
    done
  fi
  if [[ -n "$REMOVE_RAW" ]]; then
    for token in $(parse_tokens_into_raw_list "$REMOVE_RAW"); do
      args+=(--remove "$token")
    done
  fi
  [[ -n "$PACKAGE_MANAGER" ]] && args+=(--package-manager "$PACKAGE_MANAGER")
  [[ "$NO_UPDATE" -eq 1 ]] && args+=(--no-update)
  [[ "$DRY_RUN" -eq 1 ]] && args+=(--dry-run)
  [[ "$STRICT" -eq 1 ]] && args+=(--strict)

  "$INSTALL_SCRIPT" "${args[@]}"
}

prompt_menu() {
  while true; do
    render_menu_screen
    printf '%sSelect an option [1-9]: %s' "$CLR_YELLOW$CLR_BOLD" "$CLR_RESET"
    read -r choice
    case "$choice" in
      1)
        USER_SET_PROFILES=1
        PROFILES_RAW="core"
        WITH_EXTRAS=0
        ADD_RAW=""
        REMOVE_RAW=""
        run_install
        ;;
      2)
        USER_SET_PROFILES=1
        PROFILES_RAW="core,ui,api,infra,quality"
        WITH_EXTRAS=0
        ADD_RAW=""
        REMOVE_RAW=""
        run_install
        ;;
      3)
        detect_package_manager
        ensure_supported_manager || continue
        resolve_selected_packages "$PACKAGE_MANAGER"
        update_packages "${TARGET_PACKAGES[@]}"
        ;;
      4)
        detect_package_manager
        ensure_supported_manager || continue
        resolve_selected_packages "$PACKAGE_MANAGER"
        reinstall_packages "${TARGET_PACKAGES[@]}"
        ;;
      5)
        detect_package_manager
        ensure_supported_manager || continue
        printf 'Enter package names (space-separated): '
        read -r custom
        if [[ -z "$custom" ]]; then
          warn "No packages entered."
          continue
        fi
        local pkgs=()
        # shellcheck disable=SC2206
        pkgs=($custom)
        add_packages "${pkgs[@]}"
        ;;
      6)
        detect_package_manager
        ensure_supported_manager || continue
        doctor "$PACKAGE_MANAGER"
        ;;
      7)
        local repo_root
        repo_root="$(resolve_repo_root "")" || { warn "Could not resolve repo root."; continue; }
        init_repo_gitignore "$repo_root"
        ;;
      8)
        detect_package_manager
        ensure_supported_manager || continue
        show_profiles "$PACKAGE_MANAGER"
        ;;
      9)
        log "Bye."
        break
        ;;
      *)
        warn "Invalid option: $choice"
        ;;
    esac
  done
}

parse_global_flags() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --profiles)
        shift
        [[ $# -eq 0 ]] && { err "--profiles requires a value"; return 1; }
        PROFILES_RAW="$1"
        USER_SET_PROFILES=1
        ;;
      --extras) WITH_EXTRAS=1 ;;
      --add)
        shift
        [[ $# -eq 0 ]] && { err "--add requires a value"; return 1; }
        ADD_RAW="$ADD_RAW $(tokenize_csv "$1")"
        ;;
      --remove)
        shift
        [[ $# -eq 0 ]] && { err "--remove requires a value"; return 1; }
        REMOVE_RAW="$REMOVE_RAW $(tokenize_csv "$1")"
        ;;
      --no-update) NO_UPDATE=1 ;;
      --strict) STRICT=1 ;;
      --dry-run) DRY_RUN=1 ;;
      --package-manager)
        shift
        [[ $# -eq 0 ]] && { err "--package-manager requires a value"; return 1; }
        PACKAGE_MANAGER="$1"
        ;;
      *)
        err "Unknown option: $1"
        return 1
        ;;
    esac
    shift
  done
}

main() {
  local command="${1:-}"
  init_ui
  [[ $# -gt 0 ]] && shift

  case "$command" in
    menu)
      parse_global_flags "$@" || { usage; exit 1; }
      prompt_menu
      ;;
    install)
      parse_global_flags "$@" || { usage; exit 1; }
      run_install
      ;;
    update)
      parse_global_flags "$@" || { usage; exit 1; }
      detect_package_manager
      ensure_supported_manager || exit 1
      resolve_selected_packages "$PACKAGE_MANAGER"
      update_packages "${TARGET_PACKAGES[@]}"
      ;;
    reinstall)
      parse_global_flags "$@" || { usage; exit 1; }
      detect_package_manager
      ensure_supported_manager || exit 1
      resolve_selected_packages "$PACKAGE_MANAGER"
      reinstall_packages "${TARGET_PACKAGES[@]}"
      ;;
    profiles)
      parse_global_flags "$@" || { usage; exit 1; }
      detect_package_manager
      ensure_supported_manager || exit 1
      show_profiles "$PACKAGE_MANAGER"
      ;;
    add)
      local packages=()
      while [[ $# -gt 0 ]]; do
        case "$1" in
          --package-manager)
            shift
            [[ $# -eq 0 ]] && { err "--package-manager requires a value"; exit 1; }
            PACKAGE_MANAGER="$1"
            ;;
          --dry-run) DRY_RUN=1 ;;
          --strict) STRICT=1 ;;
          --no-update) NO_UPDATE=1 ;;
          *)
            packages+=("$1")
            ;;
        esac
        shift
      done
      detect_package_manager
      ensure_supported_manager || exit 1
      add_packages "${packages[@]}"
      ;;
    doctor)
      parse_global_flags "$@" || { usage; exit 1; }
      detect_package_manager
      ensure_supported_manager || exit 1
      doctor "$PACKAGE_MANAGER"
      ;;
    init)
      local repo_path=""
      while [[ $# -gt 0 ]]; do
        case "$1" in
          --repo)
            shift
            [[ $# -eq 0 ]] && { err "--repo requires a path"; exit 1; }
            repo_path="$1"
            ;;
          --dry-run) DRY_RUN=1 ;;
          *)
            err "Unknown option for init: $1"
            exit 1
            ;;
        esac
        shift
      done
      local repo_root
      repo_root="$(resolve_repo_root "$repo_path")" || { err "Could not resolve target repo."; exit 1; }
      init_repo_gitignore "$repo_root"
      ;;
    -h|--help|"")
      usage
      ;;
    *)
      err "Unknown command: $command"
      usage
      exit 1
      ;;
  esac
}

main "$@"
