---
description: "With a break-check ledger in the checkout, pass 3 marks the branch whose row holds at the head ✅ proven, flags the row whose from is gone, and asks for a break on the tested branch with no row."
tags: [recall]
max_turns: 80
timeout_seconds: 1500
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
intent: "Members can archive one of their wishes; an archived wish stays archived."
necessity: "One change; it matches the ticket."
outside_context: none
runtime: ["archive_wish/2 is called from a GraphQL mutation, once per click"]
effects: intended
production_stats: unknown
writes: { report: approve, memory: decline, gitignore: decline }
report_path: .reviews/break-checks.md
```
