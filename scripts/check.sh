#!/usr/bin/env bash
# check.sh — one-shot repo health gate. Replaces a handful of manual greps.
# Exit 0 = all pass. Exit 1 = at least one FAIL. WARNs never fail the run.
# session.sh end and release.sh refuse to push on a FAIL.
cd "$(git rev-parse --show-toplevel)"
. scripts/lib.sh 2>/dev/null || true
fail=0
pass() { printf "  PASS  %s\n" "$1"; }
warn() { printf "  WARN  %s\n" "$1"; }
bad()  { printf "  FAIL  %s\n" "$1"; fail=$((fail+1)); }
cfg()  { bash scripts/cfg.sh "$1" "${2:-}" 2>/dev/null || echo "${2:-}"; }

# Kit mode: this repo IS claude_init, not a project scaffolded from it. Its
# templates/ legitimately contain placeholders and it has no CLAUDE/ dir, so
# the project-only checks would fail spuriously.
KIT=0
[ -f project-init.md ] && [ -d templates ] && [ ! -d CLAUDE ] && KIT=1

echo "CHECK $(basename "$PWD")$( [ $KIT -eq 1 ] && echo ' (kit mode)' )"

# 1. unfilled template placeholders — only in kit-managed files. A whole-repo
# scan false-positives on Hugo/Jinja/JS templates ({{ .Title }}), so the scan is
# scoped and the token shape is exact: {{UPPER_SNAKE}}.
if [ $KIT -eq 1 ]; then
  SCOPE="README.md CHANGELOG.txt ROADMAP.md TODO.txt Makefile"
else
  SCOPE="CLAUDE .claude README.md ROADMAP.md TODO.txt CHANGELOG.txt CHANGELOG.md Makefile Makefile.kit priv/README.md VERSION"
fi
ph=""
for p in $SCOPE; do
  [ -e "$p" ] || continue
  ph="$ph $(grep -rlE '\{\{[A-Z][A-Z0-9_]*\}\}' --exclude-dir=legacy "$p" 2>/dev/null | tr '\n' ' ')"
done
ph=$(echo "$ph" | tr -s ' ')
[ -z "${ph// /}" ] && pass "no unfilled {{PLACEHOLDERS}}" || bad "unfilled placeholders in:$ph"

# 2. shell + python + json syntax
bs=0; for f in scripts/*.sh scripts/hooks/*; do [ -f "$f" ] && { bash -n "$f" 2>/dev/null || { bad "syntax: $f"; bs=1; }; }; done
for f in scripts/*.py; do [ -f "$f" ] && { python3 -m py_compile "$f" 2>/dev/null || { bad "syntax: $f"; bs=1; }; }; done
for f in CLAUDE/project.json .claude/settings.json .claude/settings.local.json; do
  [ -f "$f" ] && { python3 -c "import json,sys; json.load(open(sys.argv[1]))" "$f" 2>/dev/null || { bad "invalid JSON: $f"; bs=1; }; }
done
[ $bs -eq 0 ] && pass "scripts and JSON parse"
rm -rf scripts/__pycache__

# 3. VERSION agrees with CHANGELOG; changelog well-formed
CHLOG=$(cfg release.changelog CHANGELOG.txt)
if [ -f VERSION ] && [ -f "$CHLOG" ]; then
  v=$(tr -d ' \n' < VERSION)
  if [ "$v" = "0.1.0" ] || grep -q "^## \[$v\]" "$CHLOG"; then
    pass "VERSION $v present in $CHLOG"
  else
    bad "VERSION $v has no section in $CHLOG"
  fi
  python3 scripts/changelog.py lint >/dev/null 2>&1 && pass "changelog format" \
    || bad "changelog format (run: python3 scripts/changelog.py lint)"
fi

# 4. tag agrees with VERSION
t=$(git describe --tags --abbrev=0 2>/dev/null || echo "")
if [ -n "$t" ]; then
  [ "v$(tr -d ' \n' < VERSION 2>/dev/null)" = "$t" ] && pass "latest tag $t matches VERSION" \
    || warn "latest tag $t != v$(cat VERSION 2>/dev/null) (expected mid-cycle)"
fi

# 5. CLAUDE symlink, layout mode, skills location, Claude Code settings
cmode=$(cfg claude_repo.mode tracked)
if [ $KIT -eq 1 ]; then
  [ -f templates/CLAUDE.md ] && pass "kit templates present" || bad "templates/CLAUDE.md missing"
  grep -qE '\{\{[A-Z][A-Z0-9_]*\}\}' templates/CLAUDE.md && bad "templates/CLAUDE.md must stay invariant (no placeholders)" \
    || pass "templates/CLAUDE.md invariant"
  python3 -c 'import json; json.load(open("templates/claude-settings.json"))' 2>/dev/null \
    && pass "templates/claude-settings.json valid" || bad "templates/claude-settings.json missing or invalid"
elif [ -e CLAUDE/CLAUDE.md ]; then
  [ -L CLAUDE.md ] && pass "CLAUDE.md symlink intact" || bad "CLAUDE.md symlink missing (ln -sf CLAUDE/CLAUDE.md CLAUDE.md)"
  if [ -d .claude/skills ]; then
    { [ -L CLAUDE/skills ] && [ -d CLAUDE/skills ]; } && pass "skills in .claude/skills (CLAUDE/skills symlinked)" \
      || warn "CLAUDE/skills is not a symlink to ../.claude/skills — Claude Code only discovers .claude/skills"
  else
    warn ".claude/skills missing — Claude Code will find no project skills"
  fi
  [ -f .claude/settings.json ] && pass ".claude/settings.json present" \
    || warn ".claude/settings.json missing — no SessionStart digest hook or permission rules in Claude Code"
  if [ "$cmode" = subrepo ]; then
    [ -d CLAUDE/.git ] && pass "CLAUDE/ sub-repo present" || bad "mode=subrepo but CLAUDE/.git is missing"
    git check-ignore -q CLAUDE/ 2>/dev/null && pass "CLAUDE/ ignored by parent" || bad "mode=subrepo but CLAUDE/ is not gitignored"
    if [ -d CLAUDE/.git ]; then
      (cd CLAUDE && git remote get-url origin >/dev/null 2>&1) \
        && { (cd CLAUDE && [ -z "$(git status --porcelain)" ]) && pass "CLAUDE/ committed" || warn "CLAUDE/ has uncommitted changes"; } \
        || warn "CLAUDE/ has no remote — your notes will not travel to another machine"
    fi
  else
    git ls-files --error-unmatch CLAUDE/CLAUDE.md >/dev/null 2>&1 \
      && pass "CLAUDE/ tracked in the main repo" \
      || bad "mode=tracked but CLAUDE/CLAUDE.md is not tracked by git"
    [ -d CLAUDE/.git ] && bad "mode=tracked but CLAUDE/.git exists — the parent will ignore that directory" || true
  fi
  [ -d CLAUDE/legacy ] && warn "CLAUDE/legacy/ present — adoption merge unfinished (adopt.md Phase 3)"
else
  bad "CLAUDE/CLAUDE.md missing"
fi

# 6. priv/ ignore rules actually work
if [ -d priv ]; then
  leak=0
  for f in priv/*; do
    case "$f" in priv/README.md|priv/*.example|priv/*.template|priv/.gitkeep|'priv/*') continue;; esac
    git check-ignore -q "$f" || { bad "priv/ leak: $f is not gitignored"; leak=1; }
  done
  [ $leak -eq 0 ] && pass "priv/ ignore rules correct"
  git ls-files priv/ | grep -qvE 'README.md|\.example|\.template|\.gitkeep' && bad "a secret file is TRACKED in git" || true
fi

# 7. submodules initialised, and clonable without SSH on a public repo
if [ -f .gitmodules ]; then
  git submodule status 2>/dev/null | grep -q '^-' && bad "uninitialised submodule (git submodule update --init --recursive)" \
    || pass "submodules initialised"
  if [ "$(cfg visibility private)" = public ] && grep -qE 'url *= *git@' .gitmodules; then
    warn ".gitmodules uses an SSH url — a clone without a GitHub key cannot init it (use https://)"
  fi
fi

# 8. generated files current (git-based; see lib.sh stale)
if [ $KIT -eq 0 ] && command -v generated_pairs >/dev/null 2>&1; then
  while IFS=$'\t' read -r src art; do
    [ -n "$src" ] || continue
    if [ ! -f "$art" ]; then warn "$art not generated yet (make docs)"
    elif stale "$src" "$art"; then bad "$art stale vs $src (make docs)"
    else pass "$art current vs $src"; fi
  done < <(generated_pairs)
fi

# 9. project-specific checks (project-owned, never touched by --update)
if [ -f scripts/check.local.sh ]; then
  echo "  ---   scripts/check.local.sh"
  if bash scripts/check.local.sh; then pass "project checks (check.local.sh)"; else bad "project checks failed (scripts/check.local.sh)"; fi
fi

# 10. branch hygiene
b=$(git rev-parse --abbrev-ref HEAD)
rel=$(cfg git.release_branch main)
[ "$b" = "$rel" ] && warn "on $rel — work belongs on dev or a feature branch" || pass "on $b"
[ -z "$(git status --porcelain)" ] && pass "worktree clean" || warn "uncommitted changes ($(git status --porcelain | wc -l | tr -d ' ') files)"

echo
[ $fail -eq 0 ] && echo "check: OK" || echo "check: $fail FAILURE(S)"
exit $fail
