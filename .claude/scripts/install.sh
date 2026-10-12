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
#           up-to-date vim (always with +python3, which UltiSnips needs)
#           and neovim, ripgrep, fd, universal-ctags, pandoc, glow and a C
#           toolchain. The only mode that asks for a password.
#
# Package source per platform (heavy mode):
#   macOS Intel          MacPorts (vim/macvim get the newest +python3XX variant)
#   macOS Apple Silicon  Homebrew
#   Linux                the distro's package manager, python3-enabled vim
#                        (vim-nox on apt, vim-enhanced on dnf/yum)
#   Windows              winget, from Git Bash / MSYS2 (no sudo). WSL2 is Linux.
#
# Idempotent — safe to re-run in any mode at any time; every step checks
# current state before changing anything, and nothing pre-existing is ever
# deleted (old symlinks/dirs are moved aside with a timestamped suffix).
#
# Windows natively (Git Bash / MSYS2): symlinks need Developer Mode or an
# elevated shell; config goes to ~/vimfiles, ~/_vimrc and %LOCALAPPDATA%\nvim.
set -euo pipefail

MODE="normal"
ASSUME_YES=0
NO_FONT=0

usage() {
  cat <<'EOF'
usage: install.sh [light|normal|heavy] [-y|--yes] [--no-font] [-h|--help]

  light   minimal plugin set, no venv, no fonts — remote boxes/containers
  normal  full plugin set + venv + fonts, no sudo (default)
  heavy   normal, plus system packages (vim+python3/nvim/ripgrep/fd/ctags/pandoc/glow):
          MacPorts on Intel Macs, Homebrew on Apple Silicon, the distro manager
          on Linux, winget on Windows (Git Bash/MSYS2)

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
  MINGW*|MSYS*|CYGWIN*)
    OS="windows"
    command -v winget >/dev/null 2>&1 && PKG="winget"
    # make `ln -s` create real Windows symlinks instead of silent copies
    export MSYS=winsymlinks:nativestrict CYGWIN=winsymlinks:nativestrict
    ;;
  *) warn "unrecognised OS '$(uname -s)' — proceeding as generic Linux/POSIX" ; OS="linux" ;;
esac
ARCH="$(uname -m)"
if [ "$OS" = darwin ]; then
  # Intel Macs use MacPorts, Apple Silicon uses Homebrew
  if [ "$ARCH" = x86_64 ]; then PKG="port"; else PKG="brew"; fi
fi
log "mode=$MODE os=$OS arch=$ARCH pkg=$PKG wsl=$IS_WSL repo=$repo_root"

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
  if [ "$OS" = windows ]; then
    local appdata="${LOCALAPPDATA:-$HOME/AppData/Local}"
    link "$(cygpath -u "$appdata" 2>/dev/null || echo "$appdata")/nvim" "$repo_root"
    link "$HOME/vimfiles" "$repo_root"
    link "$HOME/_vimrc" "$repo_root/init.vim"
    return
  fi
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
    windows)
      warn "fonts: native Windows — install the .ttf files from $FONT_URL by hand (right-click → Install for all users)."
      return ;;
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
# Only what is missing or insufficient gets installed. "Sufficient" means:
#   vim    Vim >= 9.0 that actually loads python3 (UltiSnips needs it)
#   nvim   Neovim >= 0.9
#   ctags  Universal Ctags (exuberant/BSD ctags don't count)
#   build  a C compiler and make
#   venv   python3 -m venv works (apt splits it into python3-venv)
VIM_MIN=900
NVIM_MIN=0.9
GENERIC_TOOLS=(vim nvim rg fd ctags pandoc glow build venv)

have() { command -v "$1" >/dev/null 2>&1; }

# does this vim binary meet VIM_MIN and actually load python3? (has() also
# catches +python3/dyn builds whose DLL is missing, which `vim --version`
# would report as fine)
vim_has_python3() {
  local bin="${1:-vim}"
  have "$bin" || return 1
  "$bin" -Nu NONE -es -c "if has('python3') && v:version >= $VIM_MIN | qall! | else | cquit! | endif" </dev/null >/dev/null 2>&1
}

tool_ok() {
  case "$1" in
    vim)    vim_has_python3 vim ;;
    nvim)   have nvim && nvim --headless -u NONE -c "if has('nvim-$NVIM_MIN') | qall! | else | cquit! | endif" >/dev/null 2>&1 ;;
    fd)     have fd || have fdfind ;;
    ctags)  have ctags && ctags --version 2>/dev/null | grep -q 'Universal Ctags' ;;
    build)  { have cc || have gcc || have clang; } && have make ;;
    venv)   have python3 && python3 -c 'import venv, ensurepip' >/dev/null 2>&1 ;;
    *)      have "$1" ;;
  esac
}

# fills MISSING with the generic names that need installing, reports the rest
find_missing() {
  MISSING=()
  local t
  for t in "${GENERIC_TOOLS[@]}"; do
    if tool_ok "$t"; then echo "   ok: $t"; else MISSING+=("$t"); fi
  done
  if [ "$OS" = darwin ] && [ ! -d /Applications/MacVim.app ] && [ ! -d "$HOME/Applications/MacVim.app" ]; then
    MISSING+=(macvim)
  fi
}

# generic name -> per-manager package name(s); empty means "nothing to install
# here" (e.g. Xcode CLT supplies the toolchain on macOS)
pkg_name() {
  local generic="$1"
  case "$PKG:$generic" in
    *:nvim) [ "$PKG" = winget ] && echo "Neovim.Neovim" || echo "neovim" ;;
    *:rg) [ "$PKG" = winget ] && echo "BurntSushi.ripgrep.MSVC" || echo "ripgrep" ;;
    winget:vim) echo "vim.vim Python.Python.3.13" ;;  # vim.vim is +python3/dyn
    winget:fd) echo "sharkdp.fd" ;;
    winget:ctags) echo "UniversalCtags.Ctags" ;;
    winget:pandoc) echo "JohnMacFarlane.Pandoc" ;;
    winget:glow) echo "charmbracelet.glow" ;;
    winget:build) echo "ezwinports.make" ;;
    apt:vim) echo "vim-nox" ;;  # plain `vim` on Debian/Ubuntu has no +python3
    dnf:vim|yum:vim) echo "vim-enhanced" ;;
    apt:fd) echo "fd-find" ;;
    apt:ctags|port:ctags|brew:ctags) echo "universal-ctags" ;;
    apt:build) echo "build-essential" ;;
    dnf:build|yum:build|zypper:build) echo "gcc gcc-c++ make" ;;
    pacman:build) echo "base-devel" ;;
    apk:build) echo "build-base" ;;
    port:build|brew:build) ;;
    *:build) echo "gcc make" ;;
    apt:venv) echo "python3-venv" ;;
    *:venv) ;;  # bundled with python3 everywhere but Debian/Ubuntu
    *) echo "$generic" ;;
  esac
}

pkg_install() {
  local pkgs=("$@")
  [ "${#pkgs[@]}" -gt 0 ] || return 0
  case "$PKG" in
    apt)    sudo apt-get update -qq && sudo apt-get install -y "${pkgs[@]}" ;;
    dnf)    sudo dnf install -y "${pkgs[@]}" ;;
    yum)    sudo yum install -y "${pkgs[@]}" ;;
    pacman) sudo pacman -Sy --noconfirm --needed "${pkgs[@]}" ;;
    zypper) sudo zypper --non-interactive install "${pkgs[@]}" ;;
    apk)    sudo apk add "${pkgs[@]}" ;;
    port)   sudo port -N install "${pkgs[@]}" ;;
    brew)   brew install "${pkgs[@]}" ;;
    winget)
      local id rc=0
      for id in "${pkgs[@]}"; do
        winget install --id "$id" -e --silent --accept-source-agreements --accept-package-agreements || rc=1
      done
      return $rc ;;
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

# MacPorts has no unattended bootstrap (its installer is a .pkg per macOS
# release), so a missing install is a stop-and-tell, not a silent fallback.
ensure_port() {
  command -v port >/dev/null 2>&1 && return 0
  if [ -x /opt/local/bin/port ]; then
    export PATH="/opt/local/bin:/opt/local/sbin:$PATH"
    return 0
  fi
  warn "MacPorts not found — install it from https://www.macports.org/install.php, then re-run heavy mode"
  return 1
}

# newest pythonNNN variant a port offers, e.g. python314
port_python_variant() {
  port variants "$1" 2>/dev/null | grep -oE 'python3[0-9]+' | sed 's/^python//' | sort -un | tail -1 | sed 's/^/python/'
}

# MacPorts vim needs explicit variants; an installed vim without python is
# rebuilt in place with --enforce-variants rather than reinstalled.
port_vim() {
  if vim_has_python3 /opt/local/bin/vim; then
    warn "MacPorts vim is fine but isn't first on PATH — put /opt/local/bin ahead of $(dirname "$(command -v vim)")"
    return
  fi
  local pyvar; pyvar="$(port_python_variant vim)"
  [ -n "$pyvar" ] || { warn "could not read vim's python variants from MacPorts"; pyvar="python314"; }
  if port -q installed vim 2>/dev/null | grep -q active; then
    sudo port -N upgrade --enforce-variants vim +huge +"$pyvar"
  else
    sudo port -N install vim +huge +"$pyvar"
  fi
}

ensure_pkg_manager() {
  case "$PKG" in
    port) ensure_port ;;
    brew) ensure_brew ;;
    winget) return 0 ;;
    none)
      if [ "$OS" = windows ]; then
        warn "winget not found — install App Installer from the Microsoft Store, then re-run heavy mode"
      else
        warn "no recognised package manager — install manually: ${MISSING[*]}"
      fi
      return 1 ;;
  esac
}

step_heavy_packages() {
  log "heavy: system packages (only what's missing)"
  find_missing
  if [ "${#MISSING[@]}" -eq 0 ]; then
    echo "   everything already installed and sufficient"
    return
  fi
  echo "   missing or insufficient: ${MISSING[*]}"
  if [ "$ASSUME_YES" != 1 ]; then
    printf 'install them with %s (sudo where needed)? [y/N] ' "$PKG"
    read -r reply
    case "$reply" in y|Y|yes|YES) ;; *) warn "heavy packages skipped"; return ;; esac
  fi
  ensure_pkg_manager || return 0
  local t pkgs=()
  for t in "${MISSING[@]}"; do
    case "$PKG:$t" in
      port:vim) port_vim || warn "MacPorts vim rebuild failed" ;;
      port:macvim) pkg_install macvim +"$(port_python_variant macvim)" || warn "MacPorts macvim install failed" ;;
      brew:macvim) brew install --cask macvim || warn "macvim cask failed" ;;
      *:macvim) ;;
      *) local names; read -r -a names <<< "$(pkg_name "$t")"; pkgs+=("${names[@]}") ;;
    esac
  done
  if [ "${#pkgs[@]}" -gt 0 ]; then
    # one batch first; if it fails, retry one by one so a single bad name
    # (packages differ across distros) doesn't block the rest
    pkg_install "${pkgs[@]}" || for t in "${pkgs[@]}"; do
      pkg_install "$t" || warn "$t install failed (name may differ on, or be absent from, this platform)"
    done
  fi
  if [ "$PKG" = apt ] && ! have fd && have fdfind; then
    mkdir -p "$HOME/.local/bin"
    ln -sf "$(command -v fdfind)" "$HOME/.local/bin/fd"
    echo "   linked ~/.local/bin/fd -> fdfind (make sure ~/.local/bin is on PATH)"
  fi
  [ "$OS" = windows ] && warn "open a new shell so PATH picks up the winget installs before running vim"
  check_vim_python
}

check_vim_python() {
  hash -r 2>/dev/null || true
  if vim_has_python3 vim; then
    echo "   ok: $(command -v vim) is Vim 9+ with python3"
  else
    warn "$(command -v vim || echo vim) is older than Vim 9 or has no working python3 — UltiSnips will be disabled in vim."
    warn "  Check that the package manager's vim comes first on PATH (vim --version | grep python3)."
  fi
}

# ---- main --------------------------------------------------------------------
step_symlinks
step_data_dir
[ "$MODE" = heavy ] && step_heavy_packages
step_plugins
step_fonts

log "done. bash scripts/check.sh to verify, then open vim or nvim."
