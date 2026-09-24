---
name: orders
description: Execute work orders queued in CLAUDE/orders/ (tasks handed over by the Project chat when Desktop Commander was hung or the change was too big for a patch script). Use when Mike says "run the orders", "any orders pending", "do the work order", "/orders".
---

# Work orders

    python3 .claude/scripts/order.py list          # pending / blocked / running
    python3 .claude/scripts/order.py show <id>     # goal, constraints, done-when

If `$ARGUMENTS` names an id, execute that order; otherwise execute every
`pending` order in turn, oldest first, one at a time.

For each order:
1. Read it in full. It was written by another Claude surface without shell
   access: verify its assumptions against the repo before acting.
2. Do the work on the **current branch**, committing as you go (Conventional
   Commits). Approval gates in CLAUDE.md §3 still apply — stop and report
   rather than cross one.
3. Append a `## Result` section to the order file: what was done, what remains,
   what Mike should verify. Then exactly one of:

       python3 .claude/scripts/order.py done <id>
       python3 .claude/scripts/order.py block <id> "<one-line reason>"

4. For a `done` order: commit the Result, then delete the order and commit that
   too. `CLAUDE/orders/` is a queue, not an archive — `git log` keeps the record.

       python3 .claude/scripts/order.py rm <id>

   `rm` refuses while the Result is uncommitted, so following this order of
   operations cannot lose anything. Keep a finished order only when it earns its
   place as a document someone will come back to — a decision record, or a
   convention it defines — and say why in the Result.

A `blocked` order stays: it is live work waiting on an answer. Never edit
another order while executing one. Unattended alternative (no session open):
`python3 .claude/scripts/order.py run <id>` runs it through `claude -p`.
