#!/usr/bin/env bash
# scripts/install.sh — bootstrap this config on a freshly cloned machine.
#
#   git clone git@github.com:MikeDacre/nvim.git ~/nvim
#   bash ~/nvim/scripts/install.sh [light|normal|heavy]
#
# Three modes, no mode required root/sudo except heavy:
#   light   symlinks + data dirs + the minimal plugin set (VIM_MINIMAL=true).
#           No venv, no fonts. For remote boxes and containers.
#   normal  (default) everything light does, plus the full plugin set, the
#           Python venv (pynvim), and a Nerd Font for icons/glyphs — all
#           user-space, no sudo, no system package manager touched.
#   heavy   everything normal does, plus system packages via sudo: an
#           up-to-date vim/neovim, ripgrep, fd, universal-ctags, pandoc and a
#           C toolchain. The only mode that asks for a password.
#
# Idempotent — safe to re-run in any mode at any time; every step checks
# current state before changing anything, and nothing pre-existing is ever
# deleted (old symlinks/dirs are moved aside with a timestamped suffix).
#
# Windows: run this from WSL2 — it is treated as Linux. There is no native
# PowerShell path; a bare Windows shell is out of scope.
set -euo pipefail

MODE="normal"
ASSUME_YES=0
NO_FONT=0

usage() {
  cat <<'EOF'
usage: install.sh [light|normal|heavy] [-y|--yes] [--no-font] [-h|--help]

  light   minimal plugin set, no venv, no fonts — remote boxes/containers
  normal  full plugin set + venv + fonts, no sudo (default)
  heavy   normal, plus system packages (vim/nvim/ripgrep/fd/ctags/pandoc) via sudo

  -y, --yes   don't pause for confirmation before heavy mode's sudo installs
  --no-font   skip the Nerd Font install even in normal/heavy mode
EOF
}

for arg in "$@"; do
  case "$arg" in
    light|normal|heavy) MODE="$arg" ;;
    -y|--yes) ASSUME_YES=1 ;;
    --no-font) NO_FONT=1 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "install.sh: unrecognised argument: $arg" >&2; usage >&2; exit 1 ;;
  esac
done

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

log()  { printf '==> %s\n' "$1"; }
warn() { printf '!!  %s\n' "$1" >&2; }

# ---- platform detection ----------------------------------------------------
OS="unknown"
PKG="none"
IS_WSL=0
case "$(uname -s)" in
  Darwin) OS="darwin" ;;
  Linux)
    OS="linux"
    grep -qi microsoft /proc/version 2>/dev/null && IS_WSL=1
    if   command -v apt-get  >/dev/null 2>&1; then PKG="apt"
    elif command -v dnf      >/dev/null 2>&1; then PKG="dnf"
    elif command -v yum      >/dev/null 2>&1; then PKG="yum"
    elif command -v pacman   >/dev/null 2>&1; then PKG="pacman"
    elif command -v zypper   >/dev/null 2>&1; then PKG="zypper"
    elif command -v apk      >/dev/null 2>&1; then PKG="apk"
    fi
    ;;
  *) warn "unrecognised OS '$(uname -s)' — proceeding as generic Linux/POSIX" ; OS="linux" ;;
esac
log "mode=$MODE os=$OS pkg=$PKG wsl=$IS_WSL repo=$repo_root"

# ---- symlinks ---------------------------------------------------------------
# link <target> <source>: make target -> source. Never overwrite pre-existing
# real content or a symlink pointing elsewhere; move it aside first.
link() {
  local target="$1" source="$2"
  mkdir -p "$(dirname "$target")"
  if [ -L "$target" ]; then
    local current; current="$(readlink -f "$target" 2>/dev/null || readlink "$target")"
    [ "$current" = "$source" ] && { echo "   ok: $target -> $source"; return; }
    local backup; backup="$target.bak-$(date +%Y%m%d%H%M%S 2>/dev/null || echo old)"
    mv "$target" "$backup"
    echo "   moved old symlink $target -> $backup"
  elif [ -e "$target" ]; then
    local backup; backup="$target.bak-$(date +%Y%m%d%H%M%S 2>/dev/null || echo old)"
    mv "$target" "$backup"
    echo "   moved existing $target -> $backup"
  fi
  ln -s "$source" "$target"
  echo "   linked $target -> $source"
}

step_symlinks() {
  log "symlinks"
  link "$HOME/.config/nvim" "$repo_root"
  link "$HOME/.vim" "$repo_root"
  link "$HOME/.vimrc" "$repo_root/init.vim"
}

step_data_dir() {
  log "data directory (nvimdata/)"
  bash "$repo_root/scripts/link-data-dir.sh"
}

# ---- plugins + venv (delegates to the Makefile — one definition of "how to
# install plugins", not duplicated here) -------------------------------------
step_plugins() {
  log "plugins (mode=$MODE)"
  if [ "$MODE" = light ]; then
    VIM_MINIMAL=true make -C "$repo_root" init
  else
    make -C "$repo_root" init
  fi
}

# ---- fonts ------------------------------------------------------------------
# DejaVu Sans Mono, Nerd Font-patched: matches the guifont already set in
# gvimrc/init.vim and gives vim-devicons/nvim-web-devicons/airline the glyphs
# they need. User-space install, no sudo, on either macOS or Linux.
FONT_NAME="DejaVuSansMono Nerd Font"
FONT_URL="https://github.com/ryanoasis/nerd-fonts/releases/latest/download/DejaVuSansMono.zip"

step_fonts() {
  [ "$NO_FONT" = 1 ] && { log "fonts: skipped (--no-font)"; return; }
  [ "$MODE" = light ] && { log "fonts: skipped (light mode)"; return; }
  if [ "$IS_WSL" = 1 ]; then
    warn "fonts: running under WSL — fonts render via the Windows terminal, not this Linux install."
    warn "  Download $FONT_NAME from $FONT_URL, install the .ttf files on the Windows side, then set it in your terminal profile."
    return
  fi
  log "fonts ($FONT_NAME)"
  local dest
  case "$OS" in
    darwin) dest="$HOME/Library/Fonts" ;;
    linux)  dest="$HOME/.local/share/fonts" ;;
    *) warn "fonts: unknown OS, skipping"; return ;;
  esac
  if ls "$dest"/DejaVuSansMNerdFont*.ttf >/dev/null 2>&1 || ls "$dest"/DejaVuSansMono*Nerd*Font*.ttf >/dev/null 2>&1; then
    echo "   already installed in $dest"
    return
  fi
  if ! command -v curl >/dev/null 2>&1 || ! command -v unzip >/dev/null 2>&1; then
    warn "fonts: need curl and unzip, skipping"
    return
  fi
  mkdir -p "$dest"
  local tmp; tmp="$(mktemp -d)"
  if curl -fsSL "$FONT_URL" -o "$tmp/font.zip"; then
    unzip -oq "$tmp/font.zip" -d "$tmp/extracted" '*.ttf' '*.otf' 2>/dev/null || true
    find "$tmp/extracted" -type f \( -name '*.ttf' -o -name '*.otf' \) -exec cp {} "$dest/" \; 2>/dev/null || true
    echo "   installed to $dest"
    if [ "$OS" = linux ] && command -v fc-cache >/dev/null 2>&1; then
      fc-cache -f "$dest" >/dev/null 2>&1 || true
    fi
  else
    warn "fonts: download failed ($FONT_URL) — skipping, no other step depends on this"
  fi
  rm -rf "$tmp"
}

# ---- heavy: system packages via sudo -----------------------------------------
# generic name -> per-manager package name (falls back to the generic name)
pkg_name() {
  local generic="$1"
  case "$PKG:$generic" in
    apt:fd) echo "fd-find" ;;
    apt:ctags) echo "universal-ctags" ;;
    apt:build) echo "build-essential" ;;
    dnf:build|yum:build) echo "gcc gcc-c++ make" ;;
    pacman:build) echo "base-devel" ;;
    zypper:build) echo "gcc gcc-c++ make" ;;
    apk:build) echo "build-base" ;;
    *:build) echo "gcc make" ;;
    *) echo "$generic" ;;
  esac
}

pkg_install() {
  local pkgs=("$@")
  case "$PKG" in
    apt)    sudo apt-get update -qq && sudo apt-get install -y "${pkgs[@]}" ;;
    dnf)    sudo dnf install -y "${pkgs[@]}" ;;
    yum)    sudo yum install -y "${pkgs[@]}" ;;
    pacman) sudo pacman -Sy --noconfirm --needed "${pkgs[@]}" ;;
    zypper) sudo zypper --non-interactive install "${pkgs[@]}" ;;
    apk)    sudo apk add "${pkgs[@]}" ;;
    *) warn "no known package manager — install manually: ${pkgs[*]}"; return 1 ;;
  esac
}

ensure_brew() {
  if command -v brew >/dev/null 2>&1; then return 0; fi
  log "Homebrew not found — installing (official installer, needs sudo once)"
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  if [ -x /opt/homebrew/bin/brew ]; then eval "$(/opt/homebrew/bin/brew shellenv)"
  elif [ -x /usr/local/bin/brew ]; then eval "$(/usr/local/bin/brew shellenv)"
  fi
}

step_heavy_packages() {
  log "heavy: system packages (sudo)"
  if [ "$ASSUME_YES" != 1 ]; then
    printf 'heavy mode will use sudo/Homebrew to install/update system packages. Continue? [y/N] '
    read -r reply
    case "$reply" in y|Y|yes|YES) ;; *) warn "heavy packages skipped"; return ;; esac
  fi
  if [ "$OS" = darwin ]; then
    ensure_brew
    brew install vim neovim ripgrep fd universal-ctags pandoc || warn "some brew installs failed — check output above"
    brew install --cask macvim || warn "macvim cask failed (already installed, or no cask access)"
    return
  fi
  if [ "$PKG" = none ]; then
    warn "no recognised package manager on this Linux — skipping system packages"
    return
  fi
  local build_pkgs; read -r -a build_pkgs <<< "$(pkg_name build)"
  local fd_pkg ctags_pkg
  fd_pkg="$(pkg_name fd)"; ctags_pkg="$(pkg_name ctags)"
  pkg_install vim neovim ripgrep pandoc "${build_pkgs[@]}" || warn "core package install had failures"
  pkg_install "$fd_pkg" || warn "fd install failed (package name may differ on this distro)"
  pkg_install "$ctags_pkg" || pkg_install ctags || warn "ctags install failed (package name may differ on this distro)"
  if [ "$PKG" = apt ] && ! command -v fd >/dev/null 2>&1 && command -v fdfind >/dev/null 2>&1; then
    mkdir -p "$HOME/.local/bin"
    ln -sf "$(command -v fdfind)" "$HOME/.local/bin/fd"
    echo "   linked ~/.local/bin/fd -> fdfind (make sure ~/.local/bin is on PATH)"
  fi
  if [ "$PKG" = apt ]; then
    pkg_install python3-venv || warn "python3-venv install failed"
  fi
}

# ---- main --------------------------------------------------------------------
step_symlinks
step_data_dir
[ "$MODE" = heavy ] && step_heavy_packages
step_plugins
step_fonts

log "done. bash scripts/check.sh to verify, then open vim or nvim."
