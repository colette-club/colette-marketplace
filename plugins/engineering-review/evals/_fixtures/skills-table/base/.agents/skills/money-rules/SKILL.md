---
name: money-rules
description: How this team handles money. Use when code handles amounts.
---

# Money rules

- **MONEY-1** — Amounts are integers in cents, never floats: a float cannot hold 0.10 exactly, so sums drift.
- **MONEY-2** — A split hands out every cent: the remainder goes to the first shares, so the shares add up to the total.
