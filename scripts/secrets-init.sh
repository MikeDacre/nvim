#!/usr/bin/env bash
# secrets-init.sh — provision priv/ on a fresh clone.
# For every priv/*.example: create the real file, resolve values via 1Password
# CLI when signed in (op://... refs), otherwise prompt, then chmod 600.
# Never echoes a value. Never writes outside priv/.
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"
mkdir -p priv

OP=0
command -v op >/dev/null && op account list >/dev/null 2>&1 && OP=1
[[ $OP -eq 1 ]] && echo "1Password CLI: available" || echo "1Password CLI: not signed in — will prompt"

shopt -s nullglob
found=0
for tpl in priv/*.example priv/*.template; do
  found=1
  dest="${tpl%.*}"
  if [[ -e "$dest" ]]; then echo "keep   $dest"; continue; fi
  : > "$dest"; chmod 600 "$dest"
  mapfile -t TPL < "$tpl"
  for line in "${TPL[@]}"; do
    if [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]]; then printf '%s\n' "$line" >> "$dest"; continue; fi
    key="${line%%=*}"; val="${line#*=}"
    if [[ "$val" == op://* && $OP -eq 1 ]]; then
      if v=$(op read "$val" 2>/dev/null); then printf '%s=%s\n' "$key" "$v" >> "$dest"; echo "  $key  <- 1Password"; continue; fi
      echo "  $key  !! 1Password ref failed"
    fi
    if [[ -z "$val" || "$val" == op://* || "$val" == "CHANGEME" ]]; then
      if { : >/dev/tty; } 2>/dev/null; then
        read -r -s -p "  value for $key (blank = leave empty): " v </dev/tty || v=""; echo
      else
        v=""; echo "  $key  (no tty — left blank, fill it in yourself)"
      fi
      printf '%s=%s\n' "$key" "$v" >> "$dest"
    else
      printf '%s\n' "$line" >> "$dest"
    fi
  done
  chmod 600 "$dest"
  echo "wrote  $dest (0600)"
done
[[ $found -eq 0 ]] && echo "no priv/*.example templates — nothing to provision"

# safety net
for f in priv/*; do
  case "$f" in priv/README.md|priv/*.example|priv/*.template|priv/.gitkeep) continue;; esac
  git check-ignore -q "$f" || { echo "!! $f is NOT gitignored — fix .gitignore before committing"; exit 1; }
done
echo "all secret files are gitignored."
