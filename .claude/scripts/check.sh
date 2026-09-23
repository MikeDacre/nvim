#!/usr/bin/env bash
# check.sh — one-shot repo health gate. Replaces a handful of manual greps.
# Exit 0 = all pass. Exit 1 = at least one FAIL. WARNs never fail the run.
# session.sh end and release.sh refuse to push on a FAIL.
# lib.sh is required: sourcing it with `|| true` let a failed source set
# GIT=0 below and every git check pass by omission.
. "$(cd "$(dirname "$0")" && pwd)/lib.sh" || { echo "check: cannot source scripts/lib.sh"; exit 1; }
cd "$(proot)" || exit 1
cfg_init
fail=0
pass() { printf "  PASS  %s\n" "$1"; }
warn() { printf "  WARN  %s\n" "$1"; }
bad()  { printf "  FAIL  %s\n" "$1"; fail=$((fail+1)); }

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
PH_VOCAB='CLAUDE_MODE|CLAUDE_REMOTE|CLONE_URL|COMPARE_URL|CONNECTOR|DATE|DEP|DESCRIPTION|ENTRYPOINT|EXAMPLES|FIELD|FIRST_GOAL|ITEM|KEY|KIT_VERSION|LANG|LICENSE|MANIFEST|ONE_LINE_PURPOSE|OPTIONS|PARAGRAPH_DESCRIPTION|PLATFORM|PROJECT_NAME|PUSH_BRANCHES|REMOTE|REPO_LINE|REQUIREMENTS|ROTATION|RUNTIME|SECOND_GOAL|SEE_ALSO|SKILL|SLUG|SOURCE_URL|SRC|SUBTYPE|SYNC|TOOL|TYPE|USAGE_EXAMPLE|USER|VCS|VERSION|VISIBILITY'
SCOPE="CLAUDE .claude README.md ROADMAP.md TODO.txt CHANGELOG.txt CHANGELOG.md Makefile Makefile.kit priv/README.md VERSION project.yaml.example"
ph=""
for p in $SCOPE; do
  [ -e "$p" ] || continue
  ph="$ph $(grep -rlE "\{\{($PH_VOCAB)\}\}" --exclude-dir=legacy --exclude-dir=patches "$p" 2>/dev/null | tr '\n' ' ')"
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
VERF=$(cfg release.version_file VERSION)
if [ -f "$VERF" ] && [ -f "$CHLOG" ]; then
  v=$(tr -d ' \n' < "$VERF")
  # 0.0.0 = scaffolded, never released: there is no section for it yet
  if [ "$v" = "0.0.0" ] || grep -q "^## \[$v\]" "$CHLOG"; then
    pass "$VERF $v present in $CHLOG"
  else
    bad "$VERF $v has no section in $CHLOG"
  fi
  python3 scripts/changelog.py lint >/dev/null 2>&1 && pass "changelog format" \
    || bad "changelog format (run: python3 scripts/changelog.py lint)"
fi

# 3d. paths.style is standard|compact — everything else in the kit that reads
# it (bootstrap.sh, adopt.sh, session.sh, release.sh, check.sh) assumes so
style=$(cfg paths.style standard)
case "$style" in
  standard|compact) pass "paths.style=$style";;
  *) bad "paths.style='$style' must be standard|compact";;
esac

# 3b. project.json version agrees with VERSION — the digest prints project.json,
# so drift here means every session reports a version the repo no longer has.
if [ -f "$VERF" ] && [ -f CLAUDE/project.json ]; then
  pv=$(cfg version "")
  v=$(tr -d ' \n' < "$VERF")
  if [ -z "$pv" ]; then :
  elif [ "$pv" = "$v" ]; then pass "CLAUDE/project.json version matches $VERF ($v)"
  else warn "CLAUDE/project.json version=$pv but $VERF=$v (release.sh syncs it; fix by hand for older drift)"
  fi
fi

# 3c. project.yaml(.example): valid YAML; the tracked example carries no
# secret value (blank or a 1pw reference only). PyYAML missing degrades to a
# WARN — the project itself is fine, only this check can't run.
for yf in project.yaml.example project.yaml; do
  [ -f "$yf" ] || continue
  if ! python3 -c 'import yaml' >/dev/null 2>&1; then
    warn "$yf present but PyYAML is not installed — can't validate it (pip install pyyaml)"; break
  fi
  yerr=$(python3 - "$yf" <<'PY' 2>&1
import sys, yaml
f = sys.argv[1]
try: c = yaml.safe_load(open(f)) or {}
except Exception as e: print(f"not valid YAML: {e}"); sys.exit(1)
if f.endswith(".example"):
    bad = [k for k, v in (c.get("keys") or {}).items()
           if v not in (None, "") and not str(v).startswith("1pw ")]
    if bad: print("secret VALUE in the tracked example for: " + ", ".join(bad)); sys.exit(1)
PY
)
  if [ $? -eq 0 ]; then pass "$yf valid$( [ "$yf" = project.yaml.example ] && echo ', no secret values' )"
  else bad "$yf: $yerr"; fi
done

# 4. tag agrees with VERSION
t=""
[ $GIT -eq 1 ] && t=$(git describe --tags --abbrev=0 2>/dev/null || echo "")
if [ -n "$t" ]; then
  [ "v$(tr -d ' \n' < "$VERF" 2>/dev/null)" = "$t" ] && pass "latest tag $t matches $VERF" \
    || warn "latest tag $t != v$(cat "$VERF" 2>/dev/null) (expected mid-cycle)"
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
  # every type named in CLAUDE.md §0c needs a rulebook, and each rulebook needs
  # the ## Always block the session digest prints
  modes_ok=1
  for m in code writing website config other administrative knowledge-base workspace; do
    if [ ! -f "templates/modes/$m.md" ]; then bad "templates/modes/$m.md missing"; modes_ok=0; continue; fi
    head -1 "templates/modes/$m.md" | grep -q "^# TYPE: $m" \
      || { bad "templates/modes/$m.md must start '# TYPE: $m'"; modes_ok=0; }
    grep -q '^## Always' "templates/modes/$m.md" \
      || { bad "templates/modes/$m.md has no '## Always' block (the digest prints it)"; modes_ok=0; }
  done
  [ $modes_ok -eq 1 ] && pass "type rulebooks present (code, writing, website, config, other, administrative, knowledge-base, workspace)"
  drift=0
  # This repo's .claude/settings.json is the template MINUS the deny rules named
  # in project.json:kit_settings_exempt_deny — here CLAUDE.md is the template's
  # SOURCE, not an installed copy, so the guard that stops a spawned project's
  # model rewriting its own rulebook would stop the kit maintaining it. Every
  # other difference is still drift. `make sync-self` applies the same list.
  if python3 - <<'PY'
import json, sys
t = json.load(open("templates/claude-settings.json"))
s = json.load(open(".claude/settings.json"))
try:    exempt = set(json.load(open("CLAUDE/project.json")).get("kit_settings_exempt_deny", []))
except Exception: exempt = set()
p = t.get("permissions", {})
p["deny"] = [r for r in p.get("deny", []) if r not in exempt]
sys.exit(0 if t == s else 1)
PY
  then :; else bad ".claude/settings.json differs from templates/claude-settings.json beyond kit_settings_exempt_deny (make sync-self)"; drift=1; fi
  cmp -s templates/CLAUDE.md CLAUDE/CLAUDE.md || { bad "CLAUDE/CLAUDE.md differs from templates/CLAUDE.md (make sync-self)"; drift=1; }
  # the invariant rulebook must name the files the scripts actually install
  # (WARN, not FAIL: templates/CLAUDE.md is an approval-gated edit — see
  # CLAUDE/patches/2026-09-21-templates-CLAUDE.new.md)
  grep -lq 'CLAUDE/MODE\.md' templates/CLAUDE.md templates/project-instructions.txt templates/modes/*.md 2>/dev/null \
    && warn "a template still names CLAUDE/MODE.md — the installed file is CLAUDE/TYPE.md: $(grep -l 'CLAUDE/MODE\.md' templates/CLAUDE.md templates/project-instructions.txt templates/modes/*.md 2>/dev/null | tr '\n' ' ')" || true
  cmp -s templates/modes/code.md CLAUDE/TYPE.md || { bad "CLAUDE/TYPE.md differs from templates/modes/code.md (make sync-self)"; drift=1; }
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

# 5b. layout v2: the kit scripts live in .claude/scripts and the root `scripts`
# is a symlink to them (the kit itself keeps scripts/ as the source)
if [ $KIT -eq 0 ]; then
  sdir=$(cfg paths.scripts scripts)
  if [ "$sdir" = ".claude/scripts" ]; then
    if [ -L scripts ] && [ "$(readlink scripts)" = ".claude/scripts" ] && [ -d .claude/scripts ]; then
      pass "scripts -> .claude/scripts"
    else
      bad "paths.scripts=.claude/scripts but the root scripts symlink is missing or wrong (ln -s .claude/scripts scripts)"
    fi
  else
    warn "paths.scripts=$sdir — the kit keeps scripts in .claude/scripts since 1.12.0 (bash <kit>/scripts/adopt.sh --update moves them)"
  fi
  if [ -L Makefile ] && [ "$(readlink Makefile)" = ".claude/Makefile" ]; then
    warn "root Makefile symlink is a 1.12.0 leftover — the kit Makefile is run as make -f .claude/Makefile (adopt.sh --update removes it)"
  fi
fi

# 5c. mode: the rulebook installed matches the mode recorded (CLAUDE.md §0c)
mode=$(cfg type "")
if [ -n "$mode" ]; then
  case "$mode" in
    code|writing|website|config|other|administrative|knowledge-base|workspace) :;;
    *) bad "project.json type=$mode is not a recognised type (code|writing|website|config|other|administrative|knowledge-base|workspace) — run adopt.sh --update to migrate";;
  esac
  # closed subtype vocabularies (ROADMAP.md "Type system v2") — only types
  # with a settled vocabulary are checked; website/knowledge-base/
  # administrative/workspace are separate, later work
  sub=$(cfg subtype "")
  # "adopted" is adopt.sh's default when --subtype is not given — a documented
  # placeholder (m_type_is_mode), not a real choice. Treat it like empty: not
  # yet classified, not wrong.
  if [ -n "$sub" ] && [ "$sub" != adopted ]; then
    case "$mode" in
      code)           vocab="library pipeline script service tool";;
      writing)        vocab="docs manuscript notes";;
      config)         vocab="environment host provisioning service";;
      administrative) vocab="business finance legal personal";;
      *)              vocab="";;
    esac
    if [ -n "$vocab" ]; then
      match=0
      for v in $vocab; do [ "$sub" = "$v" ] && match=1; done
      if [ $match -eq 1 ]; then
        pass "subtype '$sub' is in the closed vocabulary for type $mode"
      else
        bad "subtype '$sub' is not in the closed vocabulary for type $mode (${vocab// /, }) — bash <kit>/scripts/adopt.sh --update may auto-rename it, or set it by hand in CLAUDE/project.json"
      fi
    fi
  fi
  if [ ! -f CLAUDE/TYPE.md ]; then
    bad "CLAUDE/TYPE.md missing — the $mode rulebook is not installed (bash <kit>/scripts/adopt.sh --update)"
  elif head -1 CLAUDE/TYPE.md | grep -q "^# TYPE: $mode"; then
    pass "type $mode — CLAUDE/TYPE.md agrees with project.json"
  else
    bad "CLAUDE/TYPE.md is '$(head -1 CLAUDE/TYPE.md)' but project.json says type=$mode"
  fi
  case "$mode" in
    config)
      [ "$cmode" = tracked ] || bad "config mode keeps CLAUDE/ in the main repo, but claude_repo.mode=$cmode"
      [ "$(cfg visibility private)" = public ] \
        && warn "config type with a PUBLIC remote — confirm that is deliberate (TYPE.md)" || true
      [ -n "$(cfg layout.mirrors '')" ] && pass "layout.mirrors recorded" \
        || warn "layout.mirrors is empty — nothing says where these files install (TYPE.md)";;
    writing)
      [ -f CLAUDE/STYLE.md ] && pass "CLAUDE/STYLE.md present" \
        || warn "CLAUDE/STYLE.md missing — writing mode measures every draft against it"
      bdir=$(cfg content.backup_dir .backups)
      if [ $GIT -eq 1 ] && [ -d "$bdir" ] && ! git check-ignore -q "$bdir" 2>/dev/null; then
        bad "$bdir/ is not gitignored — snapshots are a safety net, not history"
      fi
      [ -n "$(cfg content.dirs '')" ] && pass "content.dirs recorded" \
        || warn "content.dirs is empty — nothing marks which files are the user's writing";;
    website)
      [ -n "$(cfg platform '')" ] && pass "platform recorded" \
        || warn "platform is empty — nothing says what this site is built with (TYPE.md)";;
  esac
fi

# 6. secrets stay out of git: project.yaml is ignored and never tracked;
# a legacy priv/ (pre-1.12) is still checked while it exists
if [ $GIT -eq 1 ]; then
  if [ -f project.yaml.example ]; then
    if [ -e project.yaml ]; then
      git check-ignore -q project.yaml && pass "project.yaml is gitignored" || bad "project.yaml is NOT gitignored (add /project.yaml to .gitignore)"
    fi
    git ls-files --error-unmatch project.yaml >/dev/null 2>&1 && bad "project.yaml is TRACKED in git — git rm --cached it and rotate every key" || true
  elif [ ! -d priv ]; then
    warn "no project.yaml.example — the secrets contract (bash <kit>/scripts/adopt.sh --update seeds it)"
  fi
  [ -d priv ] && warn "priv/ is the pre-1.12 secrets directory — move its keys into project.yaml, then git rm -r priv/"
fi
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

# 8b. the session digest fits the SessionStart hook. Over 10000 chars Claude
# Code writes it to a file and injects only the path, so the model starts
# with no facts and no sign anything is missing. Measured, not estimated.
if [ -f scripts/session.sh ]; then
  dn=$(bash scripts/session.sh ctx 2>/dev/null | wc -c | tr -d ' ')
  if [ "${dn:-0}" -gt 10000 ]; then
    bad "session digest is $dn chars — over the 10000-char hook cap (shorten rules/hazards, release the changelog)"
  elif [ "${dn:-0}" -gt 8500 ]; then
    warn "session digest is $dn chars — close to the 10000-char hook cap"
  else
    pass "session digest fits the hook cap ($dn chars)"
  fi
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
                            Makefile Makefile.kit VERSION project.yaml.example requirements.txt
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
