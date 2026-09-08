---
name: orders
description: Execute work orders queued in CLAUDE/orders/ (tasks handed over by the Project chat when Desktop Commander was hung or the change was too big for a patch script). Use when Mike says "run the orders", "any orders pending", "do the work order", "/orders".
---

# Work orders

    python3 scripts/order.py list          # pending / blocked / running
    python3 scripts/order.py show <id>     # goal, constraints, done-when

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

       python3 scripts/order.py done <id>
       python3 scripts/order.py block <id> "<one-line reason>"

Never edit another order while executing one, and never delete an order —
`done`/`blocked` ones are the record. Unattended alternative (no session open):
`python3 scripts/order.py run <id>` runs it through `claude -p`.
