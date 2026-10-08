#!/usr/bin/env bash
# venv.sh — build or repair .venv, the dedicated Python that Neovim's python3
# provider runs. init.vim pins g:python3_host_prog at .venv/bin/python3 so
# pynvim never has to be installed into whichever interpreter happens to be
# active; the cost of that choice is that when the venv's base interpreter
# goes away, the provider has nothing at all. This script is the repair.
#
# Why it is a script and not two lines in the Makefile: on 2026-10-07 a .venv
# built against ~/anaconda3 broke when that conda install was removed, leaving
# .venv/bin/python3 a dangling symlink. Neovim's provider had no interpreter,
# so UltiSnips opened its "Python 3 is not available" diagnostics buffer at
# startup — and because that buffer lands in the window vim-startify would
# have painted, the start screen silently vanished too. One dead symlink, two
# unrelated-looking symptoms.
#
# `python3 -m venv .venv` does NOT repair that. Over an existing directory it
# rewrites pyvenv.cfg but skips symlink creation for any name that already
# lexists, so a DANGLING bin/python3 survives untouched and the venv stays
# dead. --clear is what actually rebuilds, and that is the bug fixed here.
#
# It also declines to build against interpreters that are known to move:
# conda/mamba prefixes (what broke) and pyenv shims (which follow
# `pyenv global`). Preference goes to the platform's stable system python,
# whose venv records a prefix that survives patch upgrades.
#
# Idempotent — run by `make init` on every machine, safe to re-run. A healthy
# venv is left alone and reported, never rebuilt for no reason.
#
#   bash scripts/venv.sh                           build or repair as needed
#   bash scripts/venv.sh --force                   rebuild even when healthy
#   PYTHON=/path/to/python3 bash scripts/venv.sh   choose the base interpreter
set -euo pipefail
# Resolve the repo root independently of how this script was invoked. The
# sibling scripts use `dirname $0/..`, which only lands on the root when they
# are called through the `scripts` -> `.claude/scripts` symlink (`cd
# scripts/..` resolving logically); called as `.claude/scripts/venv.sh` that
# same expression yields `.claude/`. Ask git, and fall back to up-two.
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
repo_root="$(git -C "$script_dir" rev-parse --show-toplevel 2>/dev/null || true)"
[ -n "$repo_root" ] || repo_root="$(cd "$script_dir/../.." && pwd -P)"
venv="$repo_root/.venv"
vpy="$venv/bin/python3"

force=0
case "${1:-}" in
  --force) force=1 ;;
  # Two expressions, not `s/^# \?//`: BSD sed has no \? in a BRE, so the
  # one-liner silently prints the header with its comment markers intact.
  -h|--help) sed -n '2,31p' "${BASH_SOURCE[0]}" | sed -e 's/^# //' -e 's/^#$//'; exit 0 ;;
  "") ;;
  *) echo "venv: unknown argument '$1' (try --help)" >&2; exit 2 ;;
esac

# A worktree gets .venv as a symlink into the main checkout (see
# link-worktree-shared.sh and the worktree hazard in CLAUDE/project.json).
# Rebuilding through that symlink would clear the MAIN checkout's venv from
# under every other tree, so refuse and say where to run instead.
if [ -L "$venv" ]; then
  echo "venv: $venv is a symlink -> $(readlink "$venv")"
  echo "  This tree shares the main checkout's venv. Run this script there, not here."
  exit 1
fi

# -x is false for a dangling symlink, which is exactly the broken state this
# script exists for; importing pynvim then proves the interpreter really runs
# and that the provider has what it needs.
venv_healthy() {
  [ -x "$vpy" ] || return 1
  "$vpy" -c 'import pynvim' >/dev/null 2>&1 || return 1
}

report() {
  local home
  home="$(sed -n 's/^home = //p' "$venv/pyvenv.cfg" 2>/dev/null || true)"
  echo "venv: $("$vpy" -V 2>&1), pynvim $("$vpy" -c 'import pynvim; v=pynvim.VERSION; print("%d.%d.%d" % (v.major, v.minor, v.patch))' 2>/dev/null || echo '?')"
  echo "venv: base $home"
  case "$home" in
    *"/Cellar/"*|*"/versions/"*)
      echo "venv: note — that prefix is pinned to one patch version; re-run this script after a python upgrade." ;;
  esac
  echo "venv: g:python3_host_prog -> $vpy"
}

if [ "$force" -eq 0 ] && venv_healthy; then
  echo "venv: already healthy — nothing to do (--force rebuilds)"
  report
  exit 0
fi

# Reject a base interpreter whose prefix is known to move. An explicit PYTHON
# is honoured anyway (the user outranks the heuristic) but still warned about.
unstable_reason() {
  local cand="$1" resolved base
  resolved="$(command -v "$cand" 2>/dev/null || true)"
  case "$resolved" in
    */.pyenv/shims/*|*/.pyenv/versions/*) echo "a pyenv shim — moves with \`pyenv global\`"; return ;;
  esac
  base="$("$cand" -c 'import sys; print(sys.base_prefix)' 2>/dev/null || true)"
  case "$base" in
    *conda*|*/miniforge*|*/mambaforge*) echo "a conda prefix ($base) — removed conda installs are what broke this before"; return ;;
  esac
}

usable() {
  local cand="$1"
  [ -n "$cand" ] || return 1
  command -v "$cand" >/dev/null 2>&1 || return 1
  # Debian/Ubuntu ship venv separately as python3-venv; fail here, not midway.
  "$cand" -c 'import venv, ensurepip' >/dev/null 2>&1 || return 1
  [ -z "$(unstable_reason "$cand")" ] || return 1
}

candidates() {
  if [ "$(uname -s)" = "Darwin" ]; then
    # Homebrew records home as /opt/homebrew/opt/python@X.Y/bin — an opt
    # prefix, so it survives patch bumps. Apple's /usr/bin/python3 never
    # moves at all and is the last-resort floor.
    printf '%s\n' /opt/homebrew/bin/python3 /usr/local/bin/python3 \
      /Library/Frameworks/Python.framework/Versions/Current/bin/python3 \
      /usr/bin/python3
  else
    printf '%s\n' /usr/bin/python3 /usr/local/bin/python3
  fi
}

base_py=""
if [ -n "${PYTHON:-}" ]; then
  command -v "$PYTHON" >/dev/null 2>&1 || { echo "venv: PYTHON=$PYTHON is not executable" >&2; exit 1; }
  "$PYTHON" -c 'import venv, ensurepip' >/dev/null 2>&1 || {
    echo "venv: PYTHON=$PYTHON cannot create venvs (missing venv/ensurepip — on Debian: apt install python3-venv)" >&2; exit 1; }
  reason="$(unstable_reason "$PYTHON")"
  [ -n "$reason" ] && echo "venv: warning — PYTHON=$PYTHON is $reason"
  base_py="$PYTHON"
else
  while read -r cand; do
    if usable "$cand"; then base_py="$cand"; break; fi
  done <<EOF
$(candidates)
EOF
fi

# Nothing stable found: fall back to PATH python3 rather than refuse to run,
# but name the risk so a venv that dies later is not a mystery.
if [ -z "$base_py" ] && command -v python3 >/dev/null 2>&1; then
  reason="$(unstable_reason python3)"
  if "$(command -v python3)" -c 'import venv, ensurepip' >/dev/null 2>&1; then
    base_py="$(command -v python3)"
    echo "venv: no stable system python found; falling back to $base_py${reason:+ ($reason)}"
  fi
fi

if [ -z "$base_py" ]; then
  echo "venv: found no python3 that can create a venv." >&2
  echo "  macOS: brew install python3   Debian/Ubuntu: apt install python3-venv" >&2
  echo "  Or point this script at one: PYTHON=/path/to/python3 bash scripts/venv.sh" >&2
  exit 1
fi

if [ -d "$venv" ]; then
  echo "venv: rebuilding $venv with --clear (base: $base_py)"
else
  echo "venv: creating $venv (base: $base_py)"
fi

# --clear, not a bare create: see the header. This is the whole fix.
"$base_py" -m venv --clear "$venv"
"$vpy" -m pip install -q -U pip pynvim

if ! venv_healthy; then
  echo "venv: built $venv but 'import pynvim' still fails — check network access to PyPI" >&2
  exit 1
fi

echo "venv: ok"
report
