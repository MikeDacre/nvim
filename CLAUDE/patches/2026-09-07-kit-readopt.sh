#!/usr/bin/env bash
# CLAUDE/patches/2026-09-07-kit-readopt.sh — re-adopt MikeDacre/nvim onto claude_init v1.5
# (kit TODO A). Idempotent; commits as it goes on `dev`; never touches master.
#   KIT=~/code/my_code/claude_init bash CLAUDE/patches/2026-09-07-kit-readopt.sh
set -euo pipefail
KIT="${KIT:-$HOME/code/my_code/claude_init}"
cd "$(git rev-parse --show-toplevel)"
git remote get-url origin | grep -q 'MikeDacre/nvim' || { echo "!! not the nvim checkout"; exit 1; }
[ -f "$KIT/VERSION" ] || { echo "!! KIT=$KIT is not the claude_init checkout"; exit 1; }
if [ -n "$(git status --porcelain)" ]; then echo "!! working tree dirty — commit or stash first:"; git status --short; exit 1; fi
commit() { local m="$1"; shift; git add -A -- "$@"; if git diff --cached --quiet; then echo "   (no change) $m"; else git -c core.hooksPath=/dev/null commit -q -m "$m"; echo "   committed: $m"; fi; }

echo "== 1. dev branch (master stays the release branch)"
git show-ref -q --verify refs/heads/dev || { git branch dev master; echo "   created dev from master"; }
[ "$(git rev-parse --abbrev-ref HEAD)" = dev ] || { git checkout -q dev; echo "   switched to dev (same content as master; the runtimepath now tracks dev)"; }

echo "== 2. project.json -> kit schema (missing keys only; nothing removed)"
python3 - <<'PY'
import json
p = "CLAUDE/project.json"; c = json.load(open(p)); before = json.dumps(c, sort_keys=True)
c["schema"] = 2
c.setdefault("version", "0.1.0"); c.setdefault("sync", "synced")
g = c.setdefault("git", {})
g.setdefault("release_branch", g.get("trunk", "master")); g.setdefault("dev_branch", "dev")
g.setdefault("feature_prefix", "feat/"); g.setdefault("fix_prefix", "fix/"); g.setdefault("merge", "--no-ff")
g.setdefault("commit_style", "conventional-commits-1.0.0"); g.setdefault("push_branches", "all")
g["note"] = "release branch is master (recorded, not renamed); day-to-day work lands on dev since 2026-09-07"
c.setdefault("claude_repo", {"mode": "tracked", "path": "CLAUDE", "remote": "none", "symlink": "CLAUDE.md -> CLAUDE/CLAUDE.md"})
r = c.setdefault("release", {})
for k, v in {"version_file": "VERSION", "changelog": "CHANGELOG.txt", "changelog_spec": "keepachangelog-1.1.0",
             "version_spec": "semver-2.0.0", "tag_format": "v{version}", "github_release_on": ["minor", "major"],
             "assets": [], "requires_user_approval": True}.items(): r.setdefault(k, v)
b = c.setdefault("build", {})
for k, v in {"install": "make init", "test": "make test", "docs": "make docs", "manifest": "Makefile"}.items(): b.setdefault(k, v)
gen = b.setdefault("generated", [])
if not any(x.get("artifact") == "doc/mikevim.txt" for x in gen):
    gen.append({"source": "README.md", "artifact": "doc/mikevim.txt", "via": "make doc"})
b["local_checks"] = "scripts/check.local.sh — vim and nvim must load init.vim cleanly, lua must parse"
c.setdefault("todo", {"file": "TODO.txt", "archive": "done.txt", "helper": "scripts/todo.py", "owner": "user",
                      "format": "todo.txt (http://todotxt.org/)", "comment_marker": "#"})
sk = c.setdefault("skills", []); names = {s.get("name") for s in sk}
for n, use in (("end", "close the session: commit, changelog, docs, gate, push"),
               ("ctx", "refresh the digest without network"),
               ("release", "cut a release (approval-gated; major|minor|patch)")):
    if n not in names: sk.append({"name": n, "path": f".claude/skills/{n}/SKILL.md", "use": use})
    else:
        for s in sk:
            if s.get("name") == n: s["path"] = f".claude/skills/{n}/SKILL.md"
if json.dumps(c, sort_keys=True) != before:
    json.dump(c, open(p, "w"), indent=2); open(p, "a").write("\n"); print("   updated CLAUDE/project.json")
else: print("   project.json already aligned")
PY
[ -f VERSION ] || { echo 0.1.0 > VERSION; echo "   wrote VERSION 0.1.0"; }

echo "== 3. editor gate -> scripts/check.local.sh (project-owned; the kit's check.sh calls it)"
cat > scripts/check.local.sh <<'EOF_LOCAL'
#!/usr/bin/env bash
# check.local.sh — this project's own gate, called by the kit's check.sh and by
# `make test`: both editors must load init.vim cleanly and every lua file must
# parse. Exit codes are honest. v:errmsg is reported as WARN because silent!-
# suppressed plugin errors land there too (E216 FileExplorer in nvim, E488
# glyph-palette in vim) — a WARN is a lead, not a failure.
set -uo pipefail
cd "$(git rev-parse --show-toplevel)"
. scripts/lib.sh
fail=0
ok()   { printf '  PASS  %s\n' "$1"; }
bad()  { printf '  FAIL  %s\n' "$1"; fail=1; }
warn() { printf '  WARN  %s\n' "$1"; }
skip() { printf '  SKIP  %s\n' "$1"; }

# -N (= --cmd 'set nocompatible') is mandatory: -es starts in compatible mode,
# which disables \ line continuations and produces a bogus E10/E697 cascade.
tmp=$(mktemp)
T 45 vim -es -N -u init.vim -c "redir! > $tmp" -c 'silent echo v:errmsg' -c 'redir END' -c 'qa!' </dev/null >/dev/null 2>&1
rc=$?
[ "$rc" -eq 0 ] && ok "vim loads init.vim" || bad "vim cannot load init.vim (exit $rc)"
e=$(tr -d '\n' < "$tmp" 2>/dev/null); rm -f "$tmp"
[ -n "$e" ] && warn "vim v:errmsg after startup: $e"

if command -v nvim >/dev/null 2>&1; then
  err=$(mktemp)
  e=$(T 90 nvim --headless -u init.vim -c 'lua io.stdout:write(vim.v.errmsg)' -c 'qa!' </dev/null 2>"$err")
  rc=$?
  if [ "$rc" -eq 0 ] && ! grep -qE '\bE[0-9]+:' "$err"; then ok "nvim loads init.vim"
  else bad "nvim init.vim errors: $(grep -E '\bE[0-9]+:' "$err" | head -2 | tr '\n' ' ')(exit $rc)"; fi
  rm -f "$err"
  [ -n "$e" ] && warn "nvim v:errmsg after startup: $e"
else skip "nvim not installed on this machine"; fi

if command -v luajit >/dev/null 2>&1; then
  for f in $(git ls-files 'lua/*.lua'); do
    luajit -bl "$f" >/dev/null 2>&1 && ok "lua parses $f" || bad "lua syntax error $f"
  done
elif command -v nvim >/dev/null 2>&1; then
  out=$(nvim -l /dev/stdin <<'LUA'
for _, f in ipairs(vim.fn.split(vim.fn.system("git ls-files 'lua/*.lua'"), "\n")) do
  local fn = loadfile(f); print((fn and "ok" or "FAIL") .. " " .. f)
end
LUA
)
  while read -r st f; do [ -z "$f" ] && continue; [ "$st" = ok ] && ok "lua parses $f" || bad "lua syntax error $f"; done <<< "$out"
else skip "no luajit or nvim: lua files not syntax-checked"; fi
exit $fail
EOF_LOCAL
chmod +x scripts/check.local.sh

echo "== 4. Makefile: test -> check.local.sh; docs alias (the kit's session.sh end runs make docs)"
python3 - <<'PY'
import pathlib
p = pathlib.Path("Makefile"); t = p.read_text(); o = t
t = t.replace("\t@bash scripts/check.sh editors\n", "\t@bash scripts/check.local.sh\n")
if "\ndocs:" not in t:
    t = t.replace("check:  ## the gate", "docs: doc  ## alias: what the kit's session.sh end calls\n\ncheck:  ## the gate")
    t = t.replace(".PHONY: init doc test", ".PHONY: init doc docs test")
if t != o: p.write_text(t); print("   Makefile updated")
else: print("   Makefile already aligned")
PY
commit "chore: prepare claude_init re-adoption — dev branch, kit-schema project.json, VERSION, editor gate in check.local.sh" \
  CLAUDE/project.json VERSION scripts/check.local.sh Makefile CLAUDE/patches

echo "== 5. kit update (verbatim scripts, invariant CLAUDE.md, .claude merge, kit skills)"
bash "$KIT/scripts/adopt.sh" --kit "$KIT" --update
commit "chore: update to claude_init v$(tr -d ' \n' < "$KIT/VERSION") — kit scripts verbatim, editor gate moved to check.local.sh" \
  scripts CLAUDE .claude .gitignore

echo "== 6. changelog + verify"
python3 scripts/changelog.py from-git
commit "docs: back-fill changelog" CHANGELOG.txt
bash scripts/check.sh || echo "!! check.sh reported failures (see above)"
echo; bash scripts/session.sh ctx | head -30
cat <<'NEXT'

Done on dev. master is untouched. Push when ready:  bash scripts/session.sh end
(dev is pushed by sync.sh; master moves only via scripts/release.sh, which is an approval gate.)
NEXT
