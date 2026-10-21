---
description: "Recall for deadlocks on Python with MySQL — rows locked in cart order, an order locked against cancel_order's opposite order in untouched code, a foreign-key lock before a parent update, a wait on a worker holding the pool, and a restock that already deadlocked before the change."
tags: [recall, python]
max_turns: 90
timeout_seconds: 1800
allowed_tools: [Read, Glob, Grep, Skill, Bash, Write]
---

/engineering-review:review-companion feature

```review-answers
target: feature
base: main
role: reviewer
exclusions: confirmed
permissions: { run_tests: no, explain_local_db: no, fetch_history: no }
compare_previous_report: no
intent: "Customers place an order: stock is reserved, prices are refreshed, and the order's lines and total are written."
necessity: "One change; it matches the ticket."
outside_context: none
runtime: unknown
effects: intended
production_stats: unknown
```
