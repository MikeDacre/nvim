#!/usr/bin/env python3
"""CHANGELOG.txt helper. Keep a Changelog 1.1.0.

Commands:
  from-git   append unlogged commits to [Unreleased]
  pending    print count of unlogged commits (digest use)
  sync       mark HEAD as logged without writing entries
"""
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CL = ROOT / "CHANGELOG.txt"
MARK = "<!-- changelog-synced: "

TYPES = {
    "add": "Added", "new": "Added", "feat": "Added",
    "fix": "Fixed", "bug": "Fixed",
    "remove": "Removed", "rm": "Removed", "delete": "Removed",
    "deprecat": "Deprecated", "security": "Security",
}


def git(*a):
    return subprocess.run(["git", "-C", str(ROOT), *a],
                          capture_output=True, text=True).stdout.strip()


def synced_sha():
    for line in CL.read_text().splitlines():
        if line.startswith(MARK):
            return line[len(MARK):].split()[0]
    return ""


def unlogged():
    sha = synced_sha()
    rng = f"{sha}..HEAD" if sha else "-20"
    out = git("log", "--no-merges", "--format=%h\t%s", rng)
    return [l.split("\t", 1) for l in out.splitlines() if l.strip()]


def classify(subject):
    low = subject.lower()
    for key, section in TYPES.items():
        if low.startswith(key):
            return section
    return "Changed"


def from_git():
    commits = unlogged()
    if not commits:
        print("changelog: nothing to back-fill")
        return
    buckets = {}
    for sha, subject in commits:
        buckets.setdefault(classify(subject), []).append(f"- {subject} ({sha})")
    body = ""
    for section in ("Added", "Changed", "Fixed", "Removed", "Deprecated", "Security"):
        if section in buckets:
            body += f"\n### {section}\n\n" + "\n".join(reversed(buckets[section])) + "\n"
    text = CL.read_text()
    if "## [Unreleased]" not in text:
        text = re.sub(r"(\n---\n)", r"\1\n## [Unreleased]\n", text, count=1)
    text = text.replace("## [Unreleased]\n", "## [Unreleased]\n" + body, 1)
    CL.write_text(text)
    sync(quiet=True)
    print(f"changelog: back-filled {len(commits)} commit(s)")


def sync(quiet=False):
    head = git("rev-parse", "--short", "HEAD")
    lines = [l for l in CL.read_text().splitlines() if not l.startswith(MARK)]
    while lines and not lines[-1].strip():
        lines.pop()
    lines.append("")
    lines.append(f"{MARK}{head} -->")
    CL.write_text("\n".join(lines) + "\n")
    if not quiet:
        print(f"changelog: synced to {head}")


if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else "pending"
    if cmd == "from-git":
        from_git()
    elif cmd == "sync":
        sync()
    else:
        print(len(unlogged()))
