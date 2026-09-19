#!/usr/bin/env bash
# check.sh — one-shot repo health gate. Replaces a handful of manual greps.
# Exit 0 = all pass. Exit 1 = at least one FAIL. WARNs never fail the run.
# session.sh end and release.sh refuse to push on a FAIL.
. "$(cd "$(dirname "$0")" && pwd)/lib.sh" 2>/dev/null || true
cd "$(proot 2>/dev/null || git rev-parse --show-toplevel)" || exit 1
fail=0
pass() { printf "  PASS  %s\n" "$1"; }
warn() { printf "  WARN  %s\n" "$1"; }
bad()  { printf "  FAIL  %s\n" "$1"; fail=$((fail+1)); }
cfg()  { bash scripts/cfg.sh "$1" "${2:-}" 2>/dev/null || echo "${2:-}"; }

# Kit mode: this repo IS claude_init. It is also a kit-managed project (it
# dogfoods its own conventions), so the project checks run as usual and the
# kit checks in 5a run in addition. templates/ is never scanned for
# placeholders — they are the point.
KIT=0
[ -f project-init.md ] && [ -d templates ] && KIT=1

# git.vcs = none: the project root is not a repository. Every git-based check
# below stands down rather than answering about an enclosing repo.
GIT=1; have_git 2>/dev/null || GIT=0

echo "CHECK $(basename "$PWD")$( [ $KIT -eq 1 ] && echo ' (kit + project)' )$( [ $GIT -eq 0 ] && echo ' [vcs=none]' )"

# 1. unfilled template placeholders — only in kit-managed files. A whole-repo
# scan false-positives on Hugo/Jinja/JS templates ({{ .Title }}), so the scan is
# scoped. Matching is against the kit's actual placeholder vocabulary, not the
# generic {{UPPER_SNAKE}} shape: kit-managed prose legitimately quotes a
# made-up token when it talks *about* placeholders (an archived work order
# saying "fill every {{PLACEHOLDER}}", a TODO describing this very check), and
# the shape match called those unfilled. PH_VOCAB is every token bootstrap.sh
# substitutes; 5a fails if templates/ grows one that is missing here.
#
# Convention this implies: a *vocabulary* token in a kit-managed file is always
# read as unfilled, because nothing can tell it apart from a scaffolding miss.
# Prose that discusses placeholders must therefore use an example token outside
# the vocabulary ({{PLACEHOLDER}}, {{UPPER_SNAKE}}), or spell the name out
# without braces.
PH_VOCAB='CLAUDE_MODE|CLAUDE_REMOTE|CLONE_URL|COMPARE_URL|CONNECTOR|DATE|DEP|DESCRIPTION|ENTRYPOINT|EXAMPLES|FIELD|FIRST_GOAL|ITEM|KEY|KIT_VERSION|LANG|LICENSE|MANIFEST|ONE_LINE_PURPOSE|OPTIONS|PARAGRAPH_DESCRIPTION|PROJECT_NAME|PUSH_BRANCHES|REMOTE|REQUIREMENTS|ROTATION|RUNTIME|SECOND_GOAL|SEE_ALSO|SKILL|SLUG|SOURCE_URL|SRC|SUBTYPE|SYNC|TOOL|TYPE|USAGE_EXAMPLE|USER|VCS|VERSION|VISIBILITY'
SCOPE="CLAUDE .claude README.md ROADMAP.md TODO.txt CHANGELOG.txt CHANGELOG.md Makefile Makefile.kit priv/README.md VERSION"
ph=""
for p in $SCOPE; do
  [ -e "$p" ] || continue
  ph="$ph $(grep -rlE "\{\{($PH_VOCAB)\}\}" --exclude-dir=legacy "$p" 2>/dev/null | tr '\n' ' ')"
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
  # 0.0.0 = scaffolded, never released: there is no section for it yet
  if [ "$v" = "0.0.0" ] || grep -q "^## \[$v\]" "$CHLOG"; then
    pass "VERSION $v present in $CHLOG"
  else
    bad "VERSION $v has no section in $CHLOG"
  fi
  python3 scripts/changelog.py lint >/dev/null 2>&1 && pass "changelog format" \
    || bad "changelog format (run: python3 scripts/changelog.py lint)"
fi

# 3b. project.json version agrees with VERSION — the digest prints project.json,
# so drift here means every session reports a version the repo no longer has.
if [ -f VERSION ] && [ -f CLAUDE/project.json ]; then
  pv=$(cfg version "")
  v=$(tr -d ' \n' < VERSION)
  if [ -z "$pv" ]; then :
  elif [ "$pv" = "$v" ]; then pass "CLAUDE/project.json version matches VERSION ($v)"
  else warn "CLAUDE/project.json version=$pv but VERSION=$v (release.sh syncs it; fix by hand for older drift)"
  fi
fi

# 4. tag agrees with VERSION
t=""
[ $GIT -eq 1 ] && t=$(git describe --tags --abbrev=0 2>/dev/null || echo "")
if [ -n "$t" ]; then
  [ "v$(tr -d ' \n' < VERSION 2>/dev/null)" = "$t" ] && pass "latest tag $t matches VERSION" \
    || warn "latest tag $t != v$(cat VERSION 2>/dev/null) (expected mid-cycle)"
fi

# 5a. kit checks (claude_init itself): templates valid, this repo's installed
# copies in step with templates/, and every shipped script in both copy lists.
if [ $KIT -eq 1 ]; then
  [ -f templates/CLAUDE.md ] && pass "kit templates present" || bad "templates/CLAUDE.md missing"
  grep -qE '\{\{[A-Z][A-Z0-9_]*\}\}' templates/CLAUDE.md && bad "templates/CLAUDE.md must stay invariant (no placeholders)" \
    || pass "templates/CLAUDE.md invariant"
  # Keeps section 1 honest: a placeholder added to templates/ but not to
  # PH_VOCAB would be substituted at scaffold time yet never checked for.
  unknown=$(grep -rohE '\{\{[A-Z][A-Z0-9_]*\}\}' templates/ 2>/dev/null | sort -u \
    | sed -e 's/^{{//' -e 's/}}$//' | grep -vE "^($PH_VOCAB)\$" | tr '\n' ' ')
  [ -z "${unknown// /}" ] && pass "PH_VOCAB covers every placeholder in templates/" \
    || bad "templates/ uses placeholders missing from check.sh PH_VOCAB: $unknown"
  python3 -c 'import json; json.load(open("templates/claude-settings.json"))' 2>/dev/null \
    && pass "templates/claude-settings.json valid" || bad "templates/claude-settings.json missing or invalid"
  # every mode named in CLAUDE.md §0c needs a rulebook, and each rulebook needs
  # the ## Always block the session digest prints
  modes_ok=1
  for m in code config writing other; do
    if [ ! -f "templates/modes/$m.md" ]; then bad "templates/modes/$m.md missing"; modes_ok=0; continue; fi
    head -1 "templates/modes/$m.md" | grep -q "^# MODE: $m" \
      || { bad "templates/modes/$m.md must start '# MODE: $m'"; modes_ok=0; }
    grep -q '^## Always' "templates/modes/$m.md" \
      || { bad "templates/modes/$m.md has no '## Always' block (the digest prints it)"; modes_ok=0; }
  done
  [ $modes_ok -eq 1 ] && pass "mode rulebooks present (code, config, writing, other)"
  drift=0
  cmp -s templates/claude-settings.json .claude/settings.json || { bad ".claude/settings.json differs from templates/claude-settings.json (make sync-self)"; drift=1; }
  cmp -s templates/CLAUDE.md CLAUDE/CLAUDE.md || { bad "CLAUDE/CLAUDE.md differs from templates/CLAUDE.md (make sync-self)"; drift=1; }
  cmp -s templates/modes/code.md CLAUDE/MODE.md || { bad "CLAUDE/MODE.md differs from templates/modes/code.md (make sync-self)"; drift=1; }
  for d in templates/skills/*/; do
    n=$(basename "$d")
    cmp -s "$d/SKILL.md" ".claude/skills/$n/SKILL.md" 2>/dev/null || { bad ".claude/skills/$n/SKILL.md differs from templates/skills/$n (make sync-self)"; drift=1; }
  done
  [ $drift -eq 0 ] && pass "installed copies match templates/"
  miss=0
  for f in scripts/*.sh scripts/*.py; do
    n=$(basename "$f")
    # kit-only tools: they run FROM the kit against a project and are never
    # copied into one, so they are absent from both copy lists by design
    case "$n" in bootstrap.sh|adopt.sh|update.sh|migrate.py|check.local.sh) continue;; esac
    grep -q "$n" scripts/bootstrap.sh && grep -q "$n" scripts/adopt.sh \
      || { bad "scripts/$n is missing from adopt.sh KIT_SCRIPTS or the bootstrap.sh copy loop"; miss=1; }
  done
  [ $miss -eq 0 ] && pass "every kit script is in both copy lists"
fi

# 5. CLAUDE symlink, layout mode, skills location, Claude Code settings
cmode=$(cfg claude_repo.mode tracked)
if [ -e CLAUDE/CLAUDE.md ]; then
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
    if [ $GIT -eq 0 ]; then
      pass "no parent repository to ignore CLAUDE/ (vcs=none)"
    else
      git check-ignore -q CLAUDE/ 2>/dev/null && pass "CLAUDE/ ignored by parent" || bad "mode=subrepo but CLAUDE/ is not gitignored"
    fi
    if [ -d CLAUDE/.git ]; then
      (cd CLAUDE && git remote get-url origin >/dev/null 2>&1) \
        && { (cd CLAUDE && [ -z "$(git status --porcelain)" ]) && pass "CLAUDE/ committed" || warn "CLAUDE/ has uncommitted changes"; } \
        || warn "CLAUDE/ has no remote — your notes will not travel to another machine"
    fi
  elif [ $GIT -eq 0 ]; then
    bad "claude_repo.mode=tracked but there is no repository to track it (set mode=subrepo, or git.vcs=git)"
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

# 5c. mode: the rulebook installed matches the mode recorded (CLAUDE.md §0c)
mode=$(cfg type "")
if [ -n "$mode" ]; then
  case "$mode" in
    code|config|writing|other) :;;
    *) bad "project.json type=$mode is not a mode (code|config|writing|other) — run adopt.sh --update to migrate";;
  esac
  if [ ! -f CLAUDE/MODE.md ]; then
    bad "CLAUDE/MODE.md missing — the $mode rulebook is not installed (bash <kit>/scripts/adopt.sh --update)"
  elif head -1 CLAUDE/MODE.md | grep -q "^# MODE: $mode"; then
    pass "mode $mode — CLAUDE/MODE.md agrees with project.json"
  else
    bad "CLAUDE/MODE.md is '$(head -1 CLAUDE/MODE.md)' but project.json says type=$mode"
  fi
  case "$mode" in
    config)
      [ "$cmode" = tracked ] || bad "config mode keeps CLAUDE/ in the main repo, but claude_repo.mode=$cmode"
      [ "$(cfg visibility private)" = public ] \
        && warn "config mode with a PUBLIC remote — confirm that is deliberate (MODE.md)" || true
      [ -n "$(cfg layout.mirrors '')" ] && pass "layout.mirrors recorded" \
        || warn "layout.mirrors is empty — nothing says where these files install (MODE.md)";;
    writing)
      [ -f CLAUDE/STYLE.md ] && pass "CLAUDE/STYLE.md present" \
        || warn "CLAUDE/STYLE.md missing — writing mode measures every draft against it"
      bdir=$(cfg content.backup_dir .backups)
      if [ $GIT -eq 1 ] && [ -d "$bdir" ] && ! git check-ignore -q "$bdir" 2>/dev/null; then
        bad "$bdir/ is not gitignored — snapshots are a safety net, not history"
      fi
      [ -n "$(cfg content.dirs '')" ] && pass "content.dirs recorded" \
        || warn "content.dirs is empty — nothing marks which files are the user's writing";;
  esac
fi

# 6. priv/ ignore rules actually work
if [ -d priv ] && [ $GIT -eq 1 ]; then
  leak=0
  for f in priv/*; do
    case "$f" in priv/README.md|priv/*.example|priv/*.template|priv/.gitkeep|'priv/*') continue;; esac
    git check-ignore -q "$f" || { bad "priv/ leak: $f is not gitignored"; leak=1; }
  done
  [ $leak -eq 0 ] && pass "priv/ ignore rules correct"
  git ls-files priv/ | grep -qvE 'README.md|\.example|\.template|\.gitkeep' && bad "a secret file is TRACKED in git" || true
elif [ -d priv ]; then
  warn "priv/ present but there is no repository to leak into (vcs=none) — keep secrets out of the content tree anyway"
fi

# 7. submodules initialised, and clonable without SSH on a public repo
if [ -f .gitmodules ] && [ $GIT -eq 1 ]; then
  git submodule status 2>/dev/null | grep -q '^-' && bad "uninitialised submodule (git submodule update --init --recursive)" \
    || pass "submodules initialised"
  if [ "$(cfg visibility private)" = public ] && grep -qE 'url *= *git@' .gitmodules; then
    warn ".gitmodules uses an SSH url — a clone without a GitHub key cannot init it (use https://)"
  fi
fi

# 8. generated files current (git-based; see lib.sh stale)
if command -v generated_pairs >/dev/null 2>&1; then
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

# 10. branch hygiene and worktree state (git only)
if [ $GIT -eq 0 ]; then
  pass "no repository at the project root (git.vcs=none) — branch and worktree checks skipped"
  if [ -d CLAUDE/.git ]; then
    [ -z "$(cd CLAUDE && git status --porcelain)" ] && pass "CLAUDE/ sub-repo clean" \
      || warn "CLAUDE/ sub-repo has uncommitted changes"
  fi
  bdir=$(cfg content.backup_dir .backups)
  [ -d "$bdir" ] && pass "$bdir/ present — scripts/backup.sh is the only undo here" \
    || warn "no $bdir/ yet — take a snapshot before the first content write (scripts/backup.sh)"
else
  # 10. branch hygiene
  b=$(git rev-parse --abbrev-ref HEAD)
  rel=$(cfg git.release_branch main)
  dev=$(cfg git.dev_branch dev)
  if [ "$b" = "$rel" ]; then
    if [ "$rel" = "$dev" ]; then
      pass "on $rel (dev_branch == release_branch — this is the resting branch)"
    else
      warn "on $rel — work belongs on dev or a feature branch"
    fi
  else
    pass "on $b"
  fi
  # Tracked changes: no git config can hide these, so a plain status is honest.
  trk=$(git status --porcelain --untracked-files=no)
  [ -z "$trk" ] && pass "no uncommitted tracked changes" \
    || warn "uncommitted changes ($(printf '%s\n' "$trk" | wc -l | tr -d ' ') files)"

  # Untracked files are a separate question, and the old single `git status` got
  # it wrong. A project that carries untracked content by design sets
  # `git config status.showUntrackedFiles no`, and from then on a plain status
  # reports nothing — this gate printed "worktree clean" over the project's own
  # uncommitted source files, and it fronts session.sh end and release.sh.
  # Asking with -uall instead is not an option either: in a repo that contains
  # other checkouts that is thousands of lines. So ask over the paths the project
  # owns. `paths.owned` in project.json overrides the default list below.
  owned=$(cfg paths.owned "")
  [ -n "$owned" ] || owned="CLAUDE .claude scripts src bin tests docs man templates
                            README.md ROADMAP.md TODO.txt CHANGELOG.txt CHANGELOG.md
                            Makefile Makefile.kit VERSION
                            pyproject.toml package.json Cargo.toml go.mod"
  sel=""
  for p in $owned; do [ -e "$p" ] && sel="$sel $p"; done
  if [ -z "$sel" ]; then
    warn "no project-owned paths present to scan for untracked files (paths.owned)"
  else
    # shellcheck disable=SC2086  # $sel is a deliberate list of pathspecs
    un=$(git status --porcelain --untracked-files=all -- $sel 2>/dev/null | grep '^??' || true)
    if [ -z "$un" ]; then
      pass "no untracked files in project-owned paths"
    else
      bad "$(printf '%s\n' "$un" | wc -l | tr -d ' ') untracked file(s) in project-owned paths — commit them (git add <path>) or ignore them"
      printf '%s\n' "$un" | sed 's/^?? /          /'
    fi
  fi
fi

echo
[ $fail -eq 0 ] && echo "check: OK" || echo "check: $fail FAILURE(S)"
exit $fail
