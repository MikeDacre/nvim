#!/usr/bin/env python3
"""CHANGELOG.txt helper. Keep a Changelog 1.1.0.

Commands:
  from-git    append unlogged commits to [Unreleased], merged into existing sections
  pending     print count of unlogged commits (digest use)
  sync        mark HEAD as logged without writing entries
  normalize   merge duplicate section headers under [Unreleased] (idempotent)
  check       exit 1 if [Unreleased] has duplicate section headers

"Unlogged" = commits after the <!-- changelog-synced: SHA --> marker that touch
anything other than CHANGELOG.txt. If the marker is missing or is not an ancestor
of HEAD (rebase, other branch) the last 20 commits are scanned instead.
"""
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CL = ROOT / "CHANGELOG.txt"
MARK = "<!-- changelog-synced: "
ORDER = ("Added", "Changed", "Fixed", "Removed", "Deprecated", "Security")
TYPES = {
    "add": "Added", "new": "Added", "feat": "Added",
    "fix": "Fixed", "bug": "Fixed",
    "remove": "Removed", "rm": "Removed", "delete": "Removed",
    "deprecat": "Deprecated", "security": "Security",
}


def git(*a):
    return subprocess.run(["git", "-C", str(ROOT), *a],
                          capture_output=True, text=True).stdout


def synced_sha():
    for line in CL.read_text().splitlines():
        if line.startswith(MARK):
            return line[len(MARK):].split()[0]
    return ""


def unlogged():
    sha = synced_sha()
    rng = "-20"
    if sha and subprocess.run(["git", "-C", str(ROOT), "merge-base", "--is-ancestor", sha, "HEAD"],
                              capture_output=True).returncode == 0:
        rng = f"{sha}..HEAD"
    # one git call for everything: "@@<sha>\t<subject>" then the touched files
    out = git("log", "--no-merges", "--format=@@%h\t%s", "--name-only", rng)
    commits, cur = [], None
    for line in out.splitlines():
        if line.startswith("@@"):
            h, _, s = line[2:].partition("\t")
            cur = [h, s, []]
            commits.append(cur)
        elif line.strip() and cur is not None:
            cur[2].append(line.strip())
    # skip commits that only touch the changelog itself (housekeeping)
    return [(h, s) for h, s, files in commits if set(files) - {"CHANGELOG.txt"}]


def classify(subject):
    low = subject.lower()
    for key, section in TYPES.items():
        if low.startswith(key):
            return section
    return "Changed"


def unreleased_span(text):
    return re.search(r"^## \[Unreleased\][^\n]*\n(.*?)(?=^## \[|\Z)", text, re.S | re.M)


def parse_sections(body):
    secs, cur = {}, None
    for line in body.splitlines():
        m = re.match(r"^### (\w+)", line)
        if m:
            cur = m.group(1)
            secs.setdefault(cur, [])
            continue
        if line.startswith("- ") and cur and "Nothing yet" not in line and line not in secs[cur]:
            secs[cur].append(line)
    return secs


def render(secs):
    out = "## [Unreleased]\n"
    for s in list(ORDER) + [k for k in secs if k not in ORDER]:
        if secs.get(s):
            out += f"\n### {s}\n\n" + "\n".join(secs[s]) + "\n"
    return out + "\n"


def write_unreleased(secs):
    text = CL.read_text()
    m = unreleased_span(text)
    if m:
        text = text[:m.start()] + render(secs) + text[m.end():]
    else:
        text = re.sub(r"(\n---\n)", r"\1\n" + render(secs).replace("\\", "\\\\"), text, count=1)
    CL.write_text(text)


def current_sections():
    m = unreleased_span(CL.read_text())
    return parse_sections(m.group(1)) if m else {}


def duplicates():
    m = unreleased_span(CL.read_text())
    if not m:
        return []
    heads = re.findall(r"^### (\w+)", m.group(1), re.M)
    return sorted({h for h in heads if heads.count(h) > 1})


def from_git():
    commits = unlogged()
    if not commits:
        print("changelog: nothing to back-fill")
        return
    secs = current_sections()
    logged = {l for ls in secs.values() for l in ls}
    added = 0
    for sha, subject in reversed(commits):          # oldest first
        line = f"- {subject} ({sha})"
        if not any(f"({sha})" in l for l in logged):
            secs.setdefault(classify(subject), []).append(line)
            added += 1
    write_unreleased(secs)
    sync(quiet=True)
    print(f"changelog: back-filled {added} commit(s)")


def sync(quiet=False):
    head = git("rev-parse", "--short", "HEAD").strip()
    lines = [l for l in CL.read_text().splitlines() if not l.startswith(MARK)]
    while lines and not lines[-1].strip():
        lines.pop()
    lines += ["", f"{MARK}{head} -->"]
    CL.write_text("\n".join(lines) + "\n")
    if not quiet:
        print(f"changelog: synced to {head}")


if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else "pending"
    if cmd == "from-git":
        from_git()
    elif cmd == "sync":
        sync()
    elif cmd == "normalize":
        d = duplicates()
        write_unreleased(current_sections())
        print(f"changelog: merged duplicate sections: {', '.join(d) or 'none'}")
    elif cmd == "check":
        d = duplicates()
        if d:
            print(f"changelog: duplicate [Unreleased] sections: {', '.join(d)}")
            sys.exit(1)
        print("changelog: ok")
    else:
        print(len(unlogged()))
