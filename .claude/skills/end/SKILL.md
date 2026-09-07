---
name: end
description: Close the working session — commit outstanding work with the message Mike gives, back-fill CHANGELOG.txt from git, run the check.sh gate, push. Use when Mike says "end session", "wrap up", "close out", "we're done", "push and finish".
disable-model-invocation: true
---

# End the session

Run from the repo root:

    bash scripts/session.sh end "$ARGUMENTS"

- If `$ARGUMENTS` is empty and `git status --porcelain` is non-empty, ask for a
  one-line commit message first; do not invent one.
- If `check.sh` prints a FAIL, fix the cause and re-run. Never bypass the gate
  and never push by hand around it.
- WARN lines (v:errmsg) do not block; mention them in the hand-over if new.
- Report the final `pushed …` / `unlogged=` line verbatim.
