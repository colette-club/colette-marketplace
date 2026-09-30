---
description: "Recall on Python with no language skill — over-engineered provider factory, retries without idempotency, external call in a transaction, missing authorization and config docs, hardcoded secret, risk map without authorship."
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
intent: "Charge customers for orders through Stripe with retries, sign webhook payloads, read the webhook URL from configuration, and let admins refund invoices."
necessity: "One change; it matches the ticket."
outside_context: none
runtime: ["charge_customer runs in a background job that is retried when it fails", "/admin/refund is called from the support dashboard"]
effects: intended
production_stats: unknown
writes: { report: approve, memory: decline, gitignore: decline }
report_path: .reviews/billing.md
```
