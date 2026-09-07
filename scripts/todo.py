#!/usr/bin/env python3
"""todo.py — TODO.txt helper, todo.txt format (http://todotxt.org/).

  todo.py list [filter]      open tasks, priority order (filter = substring/@ctx/+proj)
  todo.py all  [filter]      include completed
  todo.py add "(A) text +proj @ctx due:YYYY-MM-DD"    creation date added if absent
  todo.py done <n> [<n>...]  mark complete (x + completion date), by list number
  todo.py pri <n> <A-Z|->    set or clear priority
  todo.py rm <n>             delete a line (asks nothing — Claude must confirm first)
  todo.py due [days]         tasks due within N days (default 7) or overdue
  todo.py archive            move completed tasks to done.txt
  todo.py stale [days]       open tasks created more than N days ago (default 60)

Line numbers are stable within a single invocation only — always `list` first.
Comment lines start with the marker in COMMENT and are preserved untouched.
"""
import datetime as dt
import os
import re
import subprocess
import sys

COMMENT = "#"   # this repo's TODO.txt uses a # legend block (the kit default is ‡)
DATE = r"\d{4}-\d{2}-\d{2}"


def root() -> str:
    r = subprocess.run(["git", "rev-parse", "--show-toplevel"],
                       capture_output=True, text=True).stdout.strip()
    return r or os.getcwd()


PATH = os.path.join(root(), "TODO.txt")
DONE = os.path.join(root(), "done.txt")
TODAY = dt.date.today().isoformat()


def load() -> list[str]:
    if not os.path.exists(PATH):
        sys.exit(f"missing {PATH}")
    with open(PATH, encoding="utf-8") as fh:
        return fh.read().splitlines()


def save(lines: list[str]) -> None:
    with open(PATH, "w", encoding="utf-8") as fh:
        fh.write("\n".join(lines).rstrip() + "\n")


def is_task(ln: str) -> bool:
    return bool(ln.strip()) and not ln.startswith(COMMENT)


def is_done(ln: str) -> bool:
    return ln.startswith("x ")


def priority(ln: str) -> str:
    m = re.match(r"^\((?P<p>[A-Z])\) ", ln)
    return m.group("p") if m else "~"          # "~" sorts after Z


def due_of(ln: str):
    m = re.search(r"\bdue:(" + DATE + r")\b", ln)
    return dt.date.fromisoformat(m.group(1)) if m else None


def created_of(ln: str):
    body = re.sub(r"^x " + DATE + r" ", "", ln)
    body = re.sub(r"^\([A-Z]\) ", "", body)
    m = re.match(r"^(" + DATE + r")\b", body)
    return dt.date.fromisoformat(m.group(1)) if m else None


def numbered(lines: list[str]) -> list[tuple[int, str]]:
    """(1-based file line number, text) for real tasks only."""
    return [(i + 1, ln) for i, ln in enumerate(lines) if is_task(ln)]


def show(rows, header: str) -> None:
    if not rows:
        print(f"{header}: none")
        return
    print(header)
    for n, ln in rows:
        d, flag = due_of(ln), ""
        if d and not is_done(ln):
            days = (d - dt.date.today()).days
            flag = "  << OVERDUE" if days < 0 else ("  << due today" if days == 0
                                                    else f"  << {days}d")
        print(f"  {n:>3}  {ln}{flag}")


def cmd_list(filt: str | None, include_done: bool) -> None:
    rows = [(n, ln) for n, ln in numbered(load())
            if (include_done or not is_done(ln))
            and (not filt or filt.lower() in ln.lower())]
    rows.sort(key=lambda r: (is_done(r[1]), priority(r[1]),
                             due_of(r[1]) or dt.date.max))
    show(rows, f"TODO ({len(rows)})")


def cmd_add(text: str) -> None:
    text = text.strip()
    m = re.match(r"^\(([A-Z])\)\s+(.*)$", text)
    pri, rest = (m.group(1), m.group(2)) if m else (None, text)
    if not re.match(r"^" + DATE + r"\b", rest):
        rest = f"{TODAY} {rest}"
    line = f"({pri}) {rest}" if pri else rest
    lines = load()
    lines.append(line)
    save(lines)
    print(f"added: {line}")


def cmd_done(nums: list[int]) -> None:
    lines = load()
    for n in sorted(nums, reverse=True):
        i = n - 1
        if i < 0 or i >= len(lines) or not is_task(lines[i]):
            print(f"  {n}: not a task line"); continue
        if is_done(lines[i]):
            print(f"  {n}: already done"); continue
        lines[i] = f"x {TODAY} {lines[i]}"
        print(f"done: {lines[i]}")
    save(lines)


def cmd_pri(n: int, p: str) -> None:
    lines = load()
    i = n - 1
    if i < 0 or i >= len(lines) or not is_task(lines[i]):
        sys.exit(f"{n}: not a task line")
    body = re.sub(r"^\([A-Z]\) ", "", lines[i])
    lines[i] = body if p == "-" else f"({p.upper()}) {body}"
    save(lines)
    print(f"pri: {lines[i]}")


def cmd_rm(n: int) -> None:
    lines = load()
    i = n - 1
    if i < 0 or i >= len(lines) or not is_task(lines[i]):
        sys.exit(f"{n}: not a task line")
    print(f"removed: {lines.pop(i)}")
    save(lines)


def cmd_due(days: int) -> None:
    limit = dt.date.today() + dt.timedelta(days=days)
    rows = [(n, ln) for n, ln in numbered(load())
            if not is_done(ln) and due_of(ln) and due_of(ln) <= limit]
    rows.sort(key=lambda r: due_of(r[1]))
    show(rows, f"due within {days}d or overdue ({len(rows)})")


def cmd_stale(days: int) -> None:
    cut = dt.date.today() - dt.timedelta(days=days)
    rows = [(n, ln) for n, ln in numbered(load())
            if not is_done(ln) and created_of(ln) and created_of(ln) < cut]
    show(rows, f"open more than {days}d ({len(rows)}) — worth reviewing")


def cmd_archive() -> None:
    lines = load()
    keep = [ln for ln in lines if not is_done(ln)]
    moved = [ln for ln in lines if is_done(ln)]
    if not moved:
        print("nothing to archive"); return
    with open(DONE, "a", encoding="utf-8") as fh:
        fh.write("\n".join(moved) + "\n")
    save(keep)
    print(f"archived {len(moved)} task(s) -> done.txt")


if __name__ == "__main__":
    a = sys.argv[1:]
    if not a:
        sys.exit(__doc__)
    c = a[0]
    try:
        if c == "list":
            cmd_list(a[1] if len(a) > 1 else None, False)
        elif c == "all":
            cmd_list(a[1] if len(a) > 1 else None, True)
        elif c == "add" and len(a) >= 2:
            cmd_add(" ".join(a[1:]))
        elif c == "done" and len(a) >= 2:
            cmd_done([int(x) for x in a[1:]])
        elif c == "pri" and len(a) == 3:
            cmd_pri(int(a[1]), a[2])
        elif c == "rm" and len(a) == 2:
            cmd_rm(int(a[1]))
        elif c == "due":
            cmd_due(int(a[1]) if len(a) > 1 else 7)
        elif c == "stale":
            cmd_stale(int(a[1]) if len(a) > 1 else 60)
        elif c == "archive":
            cmd_archive()
        else:
            sys.exit(__doc__)
    except ValueError as e:
        sys.exit(f"bad argument: {e}")
