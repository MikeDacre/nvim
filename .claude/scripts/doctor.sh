#!/usr/bin/env bash
# doctor.sh — toolchain preflight. Prints one line per tool; exits 1 if a
# REQUIRED tool is missing. Optional tools degrade gracefully.
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh" 2>/dev/null || true
cd "$(proot 2>/dev/null || echo .)" || cd .
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
if python3 -c 'import yaml' >/dev/null 2>&1; then
  printf "  ok    %-10s%s\n" "pyyaml" " $(python3 -c 'import yaml; print(yaml.__version__)' 2>/dev/null)"
elif [[ -f project.yaml || -f project.yaml.example ]]; then
  printf "  MISS  %-10srequired — project.yaml needs it: pip install pyyaml\n" "pyyaml"; fail=1
else
  printf "  --    %-10soptional — pip install pyyaml (needed once this project has a project.yaml)\n" "pyyaml"
fi
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
# every probe is bounded: `op` in particular waits on a sign-in prompt when
# run headless, and hung doctor.sh indefinitely on a Mac mini over SSH
if command -v gh >/dev/null 2>&1; then
  T 10 gh auth status >/dev/null 2>&1 </dev/null && echo "  ok    gh         authenticated" \
    || echo "  --    gh         not authenticated — gh auth login (releases will be skipped)"
fi
if command -v op >/dev/null 2>&1; then
  if grep -qE '^\s*[A-Za-z_]+:\s*(1pw |"?"?$)' project.yaml.example 2>/dev/null && grep -q '1pw ' project.yaml project.yaml.example 2>/dev/null; then
    T 10 op account list >/dev/null 2>&1 </dev/null && echo "  ok    op         signed in" \
      || echo "  --    op         not signed in — 1pw references in project.yaml will not resolve"
  else
    echo "  --    op         not probed — no 1pw references in project.yaml"
  fi
fi

echo "REPO"
git rev-parse --git-dir >/dev/null 2>&1 && echo "  ok    git repo   $(git rev-parse --abbrev-ref HEAD)" \
  || { echo "  MISS  git repo   not a git repository"; fail=1; }
[[ -f CLAUDE/project.json ]] && echo "  ok    project.json present" \
  || echo "  --    project.json missing — scripts fall back to defaults"
[[ -f project.yaml ]] && echo "  ok    project.yaml present (this machine's keys and policies)" \
  || { [[ -f project.yaml.example ]] && echo "  --    project.yaml missing — make secrets creates it from project.yaml.example"; }
[[ -f .claude/settings.json ]] && echo "  ok    .claude/settings.json (Claude Code hook + permissions)" \
  || echo "  --    .claude/settings.json missing — Claude Code gets no digest hook"
if git remote get-url origin >/dev/null 2>&1; then
  if T 10 git ls-remote --exit-code origin >/dev/null 2>&1; then echo "  ok    remote     $(git remote get-url origin)"
  else echo "  warn  remote     $(git remote get-url origin) unreachable (offline, or no key for this host)"; fi
else
  echo "  --    remote     none — commits stay local"
fi
exit $fail
