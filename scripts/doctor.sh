#!/usr/bin/env bash
# doctor.sh — toolchain preflight. Prints one line per tool; exits 1 if a
# REQUIRED tool is missing. Optional tools degrade gracefully.
cd "$(git rev-parse --show-toplevel 2>/dev/null || echo .)"
. scripts/lib.sh 2>/dev/null || true
fail=0
chk() { # chk <req|opt> <cmd> <hint> [version-cmd]
  local kind=$1 cmd=$2 hint=$3 vc=${4:-}
  if command -v "$cmd" >/dev/null 2>&1; then
    local v=""; [[ -n "$vc" ]] && v=" $(eval "$vc" 2>/dev/null | head -1)"
    printf "  ok    %-10s%s\n" "$cmd" "$v"
  elif [[ $kind == req ]]; then
    printf "  MISS  %-10s required — %s\n" "$cmd" "$hint"; fail=1
  else
    printf "  --    %-10s optional — %s\n" "$cmd" "$hint"
  fi
}
echo "TOOLCHAIN"
chk req git     "xcode-select --install"                 "git --version | cut -d' ' -f3"
chk req python3 "brew install python"                    "python3 -V | cut -d' ' -f2"
chk opt claude  "npm i -g @anthropic-ai/claude-code (the primary surface)" "claude --version"
chk opt uv      "brew install uv"                        "uv --version | cut -d' ' -f2"
chk opt gh      "brew install gh (releases)"             "gh --version | head -1 | cut -d' ' -f3"
chk opt pandoc  "brew install pandoc (man pages)"        "pandoc -v | head -1 | cut -d' ' -f2"
chk opt op      "brew install 1password-cli (secrets)"   "op --version"
chk opt make    "xcode-select --install"                 "make -v | head -1 | cut -d' ' -f3"
if command -v timeout >/dev/null 2>&1 || command -v gtimeout >/dev/null 2>&1; then
  printf "  ok    %-10s\n" "timeout"
else
  printf "  --    %-10s optional — brew install coreutils (scripts run without it, but nothing is bounded)\n" "timeout"
fi

bv=${BASH_VERSINFO[0]:-0}
if [[ $bv -lt 4 ]]; then
  printf "  warn  bash       %s — scripts are 3.2-safe, but 5.x is better: brew install bash\n" "${BASH_VERSION%%(*}"
else
  printf "  ok    bash       %s\n" "${BASH_VERSION%%(*}"
fi

echo "AUTH"
if command -v gh >/dev/null 2>&1; then
  gh auth status >/dev/null 2>&1 && echo "  ok    gh         authenticated" \
    || echo "  --    gh         not authenticated — gh auth login (releases will be skipped)"
fi
if command -v op >/dev/null 2>&1; then
  op account list >/dev/null 2>&1 && echo "  ok    op         signed in" \
    || echo "  --    op         not signed in — secrets-init will prompt instead"
fi

echo "REPO"
git rev-parse --git-dir >/dev/null 2>&1 && echo "  ok    git repo   $(git rev-parse --abbrev-ref HEAD)" \
  || { echo "  MISS  git repo   not a git repository"; fail=1; }
[[ -f CLAUDE/project.json ]] && echo "  ok    project.json present" \
  || echo "  --    project.json missing — scripts fall back to defaults"
[[ -f .claude/settings.json ]] && echo "  ok    .claude/settings.json (Claude Code hook + permissions)" \
  || echo "  --    .claude/settings.json missing — Claude Code gets no digest hook"
if git remote get-url origin >/dev/null 2>&1; then
  if T 10 git ls-remote --exit-code origin >/dev/null 2>&1; then echo "  ok    remote     $(git remote get-url origin)"
  else echo "  warn  remote     $(git remote get-url origin) unreachable (offline, or no key for this host)"; fi
else
  echo "  --    remote     none — commits stay local"
fi
exit $fail
