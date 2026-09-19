#!/usr/bin/env bash
# backup.sh — snapshot a file or directory before changing it.
#
#   backup.sh <path>...                  snapshot into .backups/<UTC stamp>/
#   backup.sh --list [path]              snapshots, newest first
#   backup.sh --restore <stamp> <path>   put a snapshot back (the current
#                                        version is snapshotted first)
#   backup.sh --prune --keep <n>         delete all but the n newest snapshots
#
# Mandatory before any content write in `writing` mode (CLAUDE/MODE.md), and
# the right move in any mode before overwriting a file the user authored.
# Works with or without git — in a project with `git.vcs: none` it is the only
# undo there is. Never writes outside the project root.
set -uo pipefail
SDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SDIR/lib.sh"
cd "$(proot)" || exit 1
ROOT="$PWD"

DEST=$(bash scripts/cfg.sh content.backup_dir .backups 2>/dev/null || echo .backups)
[ -n "$DEST" ] || DEST=.backups
STAMP=$(date -u +%Y%m%dT%H%M%SZ)

die() { echo "backup: $*" >&2; exit 1; }

# rel <path> — the path relative to the project root, or empty when it escapes.
# Python does the normalising: macOS has no dependable realpath, and a plain
# string prefix test calls ../other/file "inside" whenever the names line up.
rel() {
  python3 - "$ROOT" "$1" <<'PY'
import os, sys
root, p = os.path.realpath(sys.argv[1]), sys.argv[2]
ap = os.path.realpath(os.path.join(root, p)) if not os.path.isabs(p) else os.path.realpath(p)
r = os.path.relpath(ap, root)
print("" if r == ".." or r.startswith(".." + os.sep) else r)
PY
}

snapshot() { # snapshot <path> [stamp]
  local p="$1" stamp="${2:-$STAMP}" r d
  [ -e "$p" ] || die "no such path: $p"
  r=$(rel "$p")
  [ -n "$r" ] || die "refusing to back up a path outside the project root: $p"
  case "$r" in "$DEST"|"$DEST"/*) die "refusing to back up the backup directory itself";; esac
  d="$DEST/$stamp/$(dirname "$r")"
  mkdir -p "$d" || die "cannot create $d"
  cp -R "$p" "$d/" || die "copy failed: $p"
  echo "  saved   $r -> $DEST/$stamp/$r"
}

case "${1:-}" in
  ""|-h|--help) sed -n '2,15p' "$0" | sed 's/^# \{0,1\}//'; exit 0;;

  --list)
    [ -d "$DEST" ] || { echo "no snapshots yet ($DEST/)"; exit 0; }
    want="${2:-}"
    # ls -1 sorts lexically and the stamp is ISO, so lexical == chronological
    for s in $(ls -1 "$DEST" 2>/dev/null | sort -r); do
      [ -d "$DEST/$s" ] || continue
      files=$(cd "$DEST/$s" && find . -type f | sed 's|^\./||')
      if [ -n "$want" ]; then
        r=$(rel "$want")
        case "$(printf '%s\n' "$files")" in *"$r"*) :;; *) continue;; esac
      fi
      echo "$s"
      printf '%s\n' "$files" | sed 's/^/    /'
    done
    ;;

  --restore)
    stamp="${2:-}"; path="${3:-}"
    [ -n "$stamp" ] && [ -n "$path" ] || die "usage: backup.sh --restore <stamp> <path>"
    r=$(rel "$path"); [ -n "$r" ] || die "path outside the project root: $path"
    src="$DEST/$stamp/$r"
    [ -e "$src" ] || die "no snapshot of $r at $stamp (backup.sh --list \"$path\")"
    # restoring is itself an overwrite, so it gets its own snapshot first
    [ -e "$r" ] && snapshot "$r" "${STAMP}-pre-restore"
    mkdir -p "$(dirname "$r")"
    cp -R "$src" "$r" || die "restore failed"
    echo "  restored $r from $stamp"
    ;;

  --prune)
    keep=10
    shift
    while [ $# -gt 0 ]; do
      case "$1" in --keep) keep="${2:-10}"; shift 2;; *) shift;; esac
    done
    [ -d "$DEST" ] || { echo "no snapshots yet ($DEST/)"; exit 0; }
    n=0
    for s in $(ls -1 "$DEST" 2>/dev/null | sort -r); do
      n=$((n+1))
      [ "$n" -le "$keep" ] && continue
      rm -rf "${DEST:?}/$s" && echo "  pruned  $s"
    done
    echo "kept $keep newest of $n snapshot(s)"
    ;;

  -*) die "unknown option: $1";;

  *)
    echo "backup $STAMP"
    for p in "$@"; do snapshot "$p"; done
    ;;
esac
