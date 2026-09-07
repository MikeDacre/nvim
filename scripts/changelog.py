#!/usr/bin/env python3
"""changelog.py — Keep a Changelog 1.1.0 helper.  (python3, no dependencies)

  changelog.py add <Category> "entry text"   insert under [Unreleased]
  changelog.py from-git [--dry-run]          write entries for unlogged commits
  changelog.py pending                       count of unlogged commits (digest)
  changelog.py sync                          mark HEAD as logged, write nothing
  changelog.py lint                          validate structure / warn on drift
  changelog.py show <version|unreleased>     print one section (for release notes)
  changelog.py release <X.Y.Z> [YYYY-MM-DD]  roll [Unreleased] into a version

"Unlogged" = commits after the `<!-- changelog-synced: SHA -->` marker that
touch anything other than the changelog and whose conventional-commit type is
user-visible (feat/fix/perf/refactor/revert/security, or any type with `!`).
If the marker is missing or is not an ancestor of HEAD (rebase, other branch)
the baseline is the last tag, or the last 20 commits without one.

Spec: https://keepachangelog.com/en/1.1.0/
"""
import datetime as dt
import os
import re
import subprocess
import sys
import signal
signal.signal(signal.SIGPIPE, signal.SIG_DFL)  # quiet exit when piped into head

CATS = ["Added", "Changed", "Deprecated", "Removed", "Fixed", "Security"]
TYPE_MAP = {"feat": "Added", "add": "Added", "new": "Added",
            "fix": "Fixed", "bug": "Fixed", "perf": "Changed",
            "refactor": "Changed", "revert": "Removed", "remove": "Removed",
            "security": "Security", "deprecate": "Deprecated"}
SKIP_TYPES = {"docs", "chore", "ci", "style", "test", "build", "merge", "release"}
MARK = "<!-- changelog-synced: "


def root() -> str:
    return subprocess.run(["git", "rev-parse", "--show-toplevel"],
                          capture_output=True, text=True).stdout.strip() or "."


def _changelog_name() -> str:
    """Adopted repos may keep an existing CHANGELOG.md; project.json decides."""
    try:
        import json
        cfg = json.load(open(os.path.join(root(), "CLAUDE", "project.json")))
        return cfg.get("release", {}).get("changelog") or "CHANGELOG.txt"
    except Exception:
        return "CHANGELOG.txt"


PATH = os.path.join(root(), _changelog_name())
NAME = os.path.basename(PATH)


def git(*a) -> str:
    return subprocess.run(["git", "-C", root(), *a],
                          capture_output=True, text=True).stdout


def read() -> list[str]:
    if not os.path.exists(PATH):
        sys.exit(f"missing {PATH}")
    with open(PATH, encoding="utf-8") as fh:
        return fh.read().splitlines()


def normalise(lines: list[str]) -> list[str]:
    """Collapse blank runs and guarantee one blank line before each header."""
    out: list[str] = []
    for ln in lines:
        blank = not ln.strip()
        if blank and (not out or not out[-1].strip()):
            continue
        if (ln.startswith("### ") or ln.startswith("## ")) and out and out[-1].strip():
            out.append("")
        out.append(ln)
    return out


def write(lines: list[str]) -> None:
    with open(PATH, "w", encoding="utf-8") as fh:
        fh.write("\n".join(normalise(lines)).rstrip() + "\n")


def section_bounds(lines, header_re):
    start = None
    for i, ln in enumerate(lines):
        if re.match(header_re, ln):
            start = i
            break
    if start is None:
        return None, None
    for j in range(start + 1, len(lines)):
        if lines[j].startswith("## ["):
            while j > start + 1 and lines[j - 1].strip() in ("", "---"):
                j -= 1
            return start, j
    end = len(lines)
    while end > start + 1 and (not lines[end - 1].strip()
                               or lines[end - 1].startswith("[")
                               or lines[end - 1].startswith(MARK)):
        end -= 1
    return start, end


def _insert(lines: list[str], cat: str, text: str, quiet: bool = False) -> list[str]:
    """Insert one entry under [Unreleased]/### cat, creating what is missing."""
    s, e = section_bounds(lines, r"^## \[Unreleased\]")
    if s is None:
        lines = ["## [Unreleased]", ""] + lines
        s, e = 0, 2
    body = [b for b in lines[s:e] if b.strip() != "- Nothing yet."]
    entry = f"- {text.rstrip('.')}."
    if entry in body:
        if not quiet:
            print("duplicate entry, skipped")
        return lines
    hdr = f"### {cat}"
    if hdr in body:
        i = body.index(hdr) + 1
        while i < len(body) and body[i].startswith("- "):
            i += 1
        body.insert(i, entry)
    else:
        order = {c: n for n, c in enumerate(CATS)}
        idx = len(body)
        for i, b in enumerate(body):
            m = re.match(r"^### (\w+)", b)
            if m and order.get(m.group(1), 99) > order[cat]:
                idx = i
                break
        body[idx:idx] = ["", hdr, entry, ""]
    while body and not body[-1].strip():
        body.pop()
    body.append("")
    return lines[:s] + body + lines[e:]


def cmd_add(cat: str, text: str) -> None:
    cat = cat.capitalize()
    if cat not in CATS:
        sys.exit(f"category must be one of {', '.join(CATS)}")
    write(_insert(read(), cat, text))
    print(f"{NAME} [Unreleased] {cat}: {text}")


def cmd_show(which: str) -> None:
    lines = read()
    pat = r"^## \[Unreleased\]" if which.lower() == "unreleased" \
        else r"^## \[" + re.escape(which.lstrip("v")) + r"\]"
    s, e = section_bounds(lines, pat)
    if s is None:
        sys.exit(f"no section for {which}")
    body = [l for l in lines[s + 1:e] if l.strip() != "---" and not l.startswith(MARK)]
    print("\n".join(body).strip())


def cmd_release(version: str, date: str | None = None) -> None:
    date = date or dt.date.today().isoformat()
    lines = read()
    s, e = section_bounds(lines, r"^## \[Unreleased\]")
    if s is None:
        sys.exit("no [Unreleased] section")
    body = [b for b in lines[s + 1:e]
            if b.strip() and b.strip() not in ("---", "- Nothing yet.")]
    if not body:
        sys.exit("[Unreleased] is empty — nothing to release. Add entries first.")
    new = ["## [Unreleased]", "", f"## [{version}] - {date}", ""] + body + [""]
    lines = lines[:s] + new + lines[e:]
    lines = _links(lines, version)
    write(lines)
    _sync(quiet=True)
    print(f"rolled [Unreleased] -> [{version}] - {date}")


def _repo_url() -> str | None:
    u = git("remote", "get-url", "origin").strip()
    if not u:
        return None
    u = u.removesuffix(".git")
    if u.startswith("git@"):
        u = "https://" + u[4:].replace(":", "/", 1)
    return u


def _links(lines: list[str], version: str) -> list[str]:
    """Rewrite the trailing comparison link refs (Keep a Changelog convention)."""
    url = _repo_url()
    if not url:
        return lines
    body = [ln for ln in lines if not re.match(r"^\[[^\]]+\]:\s*http", ln)]
    while body and not body[-1].strip():
        body.pop()
    refs = [f"[Unreleased]: {url}/compare/v{version}...HEAD"]
    seen = []
    for ln in lines:
        m = re.match(r"^## \[(\d+\.\d+\.\d+)\]", ln)
        if m:
            seen.append(m.group(1))
    for i, v in enumerate(seen):
        nxt = seen[i + 1] if i + 1 < len(seen) else None
        refs.append(f"[{v}]: {url}/compare/v{nxt}...v{v}" if nxt
                    else f"[{v}]: {url}/releases/tag/v{v}")
    return body + [""] + refs


# ---------------------------------------------------------------- unlogged --

def synced_sha() -> str:
    for line in read():
        if line.startswith(MARK):
            return line[len(MARK):].split()[0]
    return ""


def _baseline() -> str:
    sha = synced_sha()
    if sha and subprocess.run(["git", "-C", root(), "merge-base", "--is-ancestor", sha, "HEAD"],
                              capture_output=True).returncode == 0:
        return f"{sha}..HEAD"
    tag = git("describe", "--tags", "--abbrev=0").strip()
    return f"{tag}..HEAD" if tag else "-20"


def _parse(subject: str):
    """-> (category, description) or None when the commit is not user-visible."""
    m = re.match(r"^(\w+)(\([^)]*\))?(!)?:\s*(.+)$", subject)
    if not m:
        return None
    typ, _, bang, desc = m.groups()
    typ = typ.lower()
    if bang:
        return "Changed", desc
    if typ in SKIP_TYPES:
        return None
    cat = TYPE_MAP.get(typ)
    return (cat, desc) if cat else None


def unlogged() -> list[tuple[str, str, str]]:
    """[(short-sha, category, description)] oldest last, newest first."""
    out = git("log", "--no-merges", "--format=@@%h\t%s", "--name-only", _baseline())
    commits, cur = [], None
    for line in out.splitlines():
        if line.startswith("@@"):
            h, _, s = line[2:].partition("\t")
            cur = [h, s, []]
            commits.append(cur)
        elif line.strip() and cur is not None:
            cur[2].append(line.strip())
    keep = []
    for h, s, files in commits:
        if not (set(files) - {NAME, "CHANGELOG.txt", "CHANGELOG.md"}):
            continue                                  # changelog housekeeping only
        p = _parse(s)
        if p:
            keep.append((h, p[0], p[1]))
    return keep


def cmd_from_git(dry: bool = False) -> None:
    items = unlogged()
    if not items:
        print(f"{NAME}: nothing to back-fill")
        if not dry and not synced_sha():      # first run only: plant the marker
            _sync(quiet=True)
        return
    lines = read()
    text = "\n".join(lines)
    added = 0
    for sha, cat, desc in reversed(items):                # oldest first
        if f"({sha})" in text:
            continue
        if dry:
            print(f"  {cat:<10} {desc} ({sha})")
        else:
            lines = _insert(lines, cat, f"{desc} ({sha})", quiet=True)
        added += 1
    if dry:
        print(f"{NAME}: {added} entr{'y' if added == 1 else 'ies'} would be added")
        return
    write(lines)
    _sync(quiet=True)
    print(f"{NAME}: back-filled {added} commit(s) — review the diff")


def _sync(quiet: bool = False) -> None:
    head = git("rev-parse", "--short", "HEAD").strip()
    lines = [l for l in read() if not l.startswith(MARK)]
    while lines and not lines[-1].strip():
        lines.pop()
    lines += ["", f"{MARK}{head} -->"]
    write(lines)
    if not quiet:
        print(f"{NAME}: synced to {head}")


def _duplicate_headers() -> list[str]:
    lines = read()
    s, e = section_bounds(lines, r"^## \[Unreleased\]")
    if s is None:
        return []
    heads = re.findall(r"^### (\w+)", "\n".join(lines[s:e]), re.M)
    return sorted({h for h in heads if heads.count(h) > 1})


def cmd_lint() -> int:
    lines = read()
    bad = []
    if not any(ln.startswith("## [Unreleased]") for ln in lines):
        bad.append("no [Unreleased] section")
    for ln in lines:
        m = re.match(r"^### (\w+)", ln)
        if m and m.group(1) not in CATS:
            bad.append(f"non-standard category: {m.group(1)}")
        m = re.match(r"^## \[(\d+\.\d+\.\d+)\] - (\S+)", ln)
        if m:
            try:
                dt.date.fromisoformat(m.group(2))
            except ValueError:
                bad.append(f"bad date on {m.group(1)}: {m.group(2)}")
    seen: dict[str, int] = {}
    cur = None
    for ln in lines:
        if ln.startswith("## ["):
            cur, seen = ln.split("]")[0] + "]", {}
        m = re.match(r"^### (\w+)", ln)
        if m and cur:
            seen[m.group(1)] = seen.get(m.group(1), 0) + 1
            if seen[m.group(1)] == 2:
                bad.append(f"duplicate section '{m.group(1)}' under {cur}")
    vf = os.path.join(root(), "VERSION")
    if os.path.exists(vf):
        v = open(vf).read().strip()
        if v != "0.1.0" and not any(f"## [{v}]" in ln for ln in lines):
            bad.append(f"VERSION={v} has no changelog section")
    if bad:
        print(f"{NAME} lint:")
        for b in bad:
            print("  !!", b)
        return 1
    print(f"{NAME} lint: ok")
    return 0


if __name__ == "__main__":
    a = sys.argv[1:]
    if not a:
        sys.exit(__doc__)
    c = a[0]
    if c == "add" and len(a) >= 3:
        cmd_add(a[1], " ".join(a[2:]))
    elif c == "show" and len(a) == 2:
        cmd_show(a[1])
    elif c == "release" and len(a) >= 2:
        cmd_release(a[1], a[2] if len(a) > 2 else None)
    elif c == "from-git":
        cmd_from_git(dry="--dry-run" in a)
    elif c == "pending":
        print(len(unlogged()))
    elif c == "sync":
        _sync()
    elif c == "lint":
        sys.exit(cmd_lint())
    else:
        sys.exit(__doc__)
