#!/usr/bin/env python3
"""order.py — work orders: a task written by one Claude surface for another.

The Project chat writes an order when Desktop Commander is hung and the change
is too big for one patch script; Claude Code executes it, interactively via
/orders or unattended via `order.py run` (which shells out to `claude -p`).

  new <slug> [-g GOAL] [-c CONSTRAINT ...] [-w DONE_WHEN ...]
        create CLAUDE/orders/<date>-<slug>.md (goal from stdin if -g omitted and stdin is piped)
  list | summary | show <id>
  run [<id> | --all] [--dry-run] [--max-turns N]   unattended: claude -p, acceptEdits
  done <id> | block <id> "reason" | reopen <id>

An order is front matter (status: pending|running|done|blocked|failed) plus
markdown sections Goal / Constraints / Done when / Result. Orders are never
deleted: done and blocked ones are the record. Logs of unattended runs go to
CLAUDE/orders/log/ (gitignored).
"""
from __future__ import annotations
import argparse, datetime as dt, json, os, re, shlex, shutil, subprocess, sys
from pathlib import Path

ROOT = Path(subprocess.check_output(["git", "rev-parse", "--show-toplevel"], text=True).strip())
DIR, LOGDIR = ROOT / "CLAUDE" / "orders", ROOT / "CLAUDE" / "orders" / "log"
TODAY = dt.date.today().isoformat()
STATES = ("pending", "running", "done", "blocked", "failed")

def cfg(*path, default=""):
    try: c = json.load(open(ROOT / "CLAUDE" / "project.json"))
    except Exception: return default
    for k in path:
        c = c.get(k) if isinstance(c, dict) else None
        if c is None: return default
    return c

def branch(): return subprocess.check_output(["git", "branch", "--show-current"], text=True, cwd=ROOT).strip()
def files(): return sorted(DIR.glob("*.md")) if DIR.is_dir() else []

def split(p: Path):
    t = p.read_text()
    m = re.match(r"^---\n(.*?)\n---\n(.*)$", t, re.S)
    if not m: return {}, t
    d = {}
    for ln in m.group(1).splitlines():
        if ":" in ln:
            k, v = ln.split(":", 1); d[k.strip()] = v.strip()
    return d, m.group(2)

def join(d: dict, body: str) -> str:
    return "---\n" + "\n".join(f"{k}: {v}" for k, v in d.items()) + "\n---\n" + body

def find(ident: str) -> Path:
    hits = [p for p in files() if p.stem == ident] or [p for p in files() if ident in p.stem]
    if len(hits) != 1: sys.exit(f"order.py: {len(hits)} orders match {ident!r}: " + ", ".join(h.stem for h in hits))
    return hits[0]

def set_status(p: Path, st: str, note: str = "") -> None:
    d, body = split(p)
    d["status"], d["updated"] = st, TODAY
    if note:
        body = body.rstrip("\n") + ("\n" if "## Result" in body else "\n\n## Result\n") + note + "\n"
    p.write_text(join(d, body))

def rel(p: Path) -> str: return str(p.relative_to(ROOT))

# ---------------------------------------------------------------- commands
def cmd_new(a):
    slug = re.sub(r"[^a-z0-9]+", "-", a.slug.lower()).strip("-")
    if not slug: sys.exit("order.py: slug must contain letters or digits")
    p = DIR / f"{TODAY}-{slug}.md"
    if p.exists(): sys.exit(f"order.py: {rel(p)} exists")
    goal = a.goal if a.goal is not None else (sys.stdin.read().strip() if not sys.stdin.isatty() else "")
    if not goal: sys.exit("order.py: give a goal with -g or on stdin")
    cons = list(a.constraint or []) + ["Approval gates in CLAUDE.md §3 still apply: stop and report rather than cross one."]
    done = list(a.done_when or []) + ["`bash scripts/check.sh` exits 0 and the work is committed on the current branch."]
    front = {"id": p.stem, "status": "pending", "created": TODAY,
             "from": os.environ.get("ORDER_FROM", "project-chat"), "branch": branch() or "?"}
    body = ("# Goal\n" + goal + "\n\n## Constraints\n" + "".join(f"- {c}\n" for c in cons)
            + "\n## Done when\n" + "".join(f"- {w}\n" for w in done))
    DIR.mkdir(parents=True, exist_ok=True)
    p.write_text(join(front, body))
    print(f"created {rel(p)}  (execute: /orders in Claude Code, or python3 scripts/order.py run {p.stem})")

def cmd_list(a):
    rows = [(p.stem, split(p)[0]) for p in files()]
    if not rows: print("no orders"); return
    for stem, d in rows:
        if a.all or d.get("status") in ("pending", "running", "blocked"):
            print(f"{d.get('status','?'):8} {stem}  created={d.get('created','?')} from={d.get('from','?')} branch={d.get('branch','?')}")

def cmd_summary(a):
    by = {}
    for p in files():
        by.setdefault(split(p)[0].get("status", "?"), []).append(p.stem)
    parts = [f"{len(by[s])} {s}: " + ", ".join(by[s][:4]) + (" …" if len(by[s]) > 4 else "")
             for s in ("running", "pending", "blocked") if by.get(s)]
    if parts: print("ORDERS   " + " · ".join(parts) + "   (python3 scripts/order.py list; /orders in Claude Code)")

def cmd_show(a): print(find(a.id).read_text(), end="")
def cmd_done(a): p = find(a.id); set_status(p, "done", a.note or ""); print(f"done    {p.stem}")
def cmd_block(a): p = find(a.id); set_status(p, "blocked", a.reason); print(f"blocked {p.stem}: {a.reason}")
def cmd_reopen(a): p = find(a.id); set_status(p, "pending"); print(f"pending {p.stem}")

PROMPT = """Execute the work order below in this repository. Read CLAUDE.md first; its rules apply.
Work on the current branch ({branch}); commit as you go with Conventional Commits; do not push or merge.
Approval-gated actions (CLAUDE.md §3) are out of scope: if one is required, stop and record it.
When finished, append a "## Result" section to {rel} (what you did, what remains, what to verify),
then run exactly one of:
  python3 scripts/order.py done {id}
  python3 scripts/order.py block {id} "<one-line reason>"

--- ORDER {rel} ---
{body}"""

def cmd_run(a):
    targets = [find(a.id)] if a.id else [p for p in files() if split(p)[0].get("status") == "pending"]
    if not targets: print("nothing to run"); return
    br = branch()
    if br == cfg("git", "release_branch", default="main"):
        sys.exit(f"order.py: on {br} — orders run on dev or a feature branch")
    claude = shutil.which("claude")
    if not claude and not a.dry_run: sys.exit("order.py: claude CLI not found (npm i -g @anthropic-ai/claude-code)")
    for p in targets:
        d, body = split(p)
        if d.get("status") != "pending" and not a.id:
            continue
        prompt = PROMPT.format(branch=br, rel=rel(p), id=p.stem, body=body)
        cmd = [claude or "claude", "-p", prompt, "--permission-mode", "acceptEdits",
               "--max-turns", str(a.max_turns), "--output-format", "text"]
        if a.dry_run:
            print(f"DRY {p.stem}: " + shlex.join(cmd[:1] + ["-p", "<prompt>"] + cmd[3:])); continue
        LOGDIR.mkdir(parents=True, exist_ok=True)
        log = LOGDIR / f"{p.stem}.{dt.datetime.now():%Y%m%d-%H%M%S}.log"
        set_status(p, "running")
        print(f"run     {p.stem} -> {rel(log)}")
        with open(log, "w") as fh:
            fh.write(prompt + "\n\n=== claude ===\n"); fh.flush()
            rc = subprocess.run(cmd, cwd=ROOT, stdin=subprocess.DEVNULL, stdout=fh, stderr=subprocess.STDOUT).returncode
        if split(p)[0].get("status") == "running":   # the executor never closed the order
            set_status(p, "failed" if rc else "blocked",
                       f"(order.py) claude exited {rc} without closing the order — review {rel(log)}")
        print(f"{split(p)[0].get('status'):8}{p.stem}  exit={rc}")

def main():
    ap = argparse.ArgumentParser(prog="order.py", description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    s = ap.add_subparsers(dest="cmd", required=True)
    n = s.add_parser("new"); n.add_argument("slug"); n.add_argument("-g", "--goal")
    n.add_argument("-c", "--constraint", action="append"); n.add_argument("-w", "--done-when", action="append"); n.set_defaults(f=cmd_new)
    l = s.add_parser("list"); l.add_argument("--all", action="store_true"); l.set_defaults(f=cmd_list)
    s.add_parser("summary").set_defaults(f=cmd_summary)
    x = s.add_parser("show"); x.add_argument("id"); x.set_defaults(f=cmd_show)
    r = s.add_parser("run"); r.add_argument("id", nargs="?"); r.add_argument("--all", action="store_true")
    r.add_argument("--dry-run", action="store_true"); r.add_argument("--max-turns", type=int, default=80); r.set_defaults(f=cmd_run)
    d = s.add_parser("done"); d.add_argument("id"); d.add_argument("note", nargs="?"); d.set_defaults(f=cmd_done)
    b = s.add_parser("block"); b.add_argument("id"); b.add_argument("reason"); b.set_defaults(f=cmd_block)
    o = s.add_parser("reopen"); o.add_argument("id"); o.set_defaults(f=cmd_reopen)
    a = ap.parse_args()
    try: a.f(a)
    except BrokenPipeError: pass

if __name__ == "__main__": main()
