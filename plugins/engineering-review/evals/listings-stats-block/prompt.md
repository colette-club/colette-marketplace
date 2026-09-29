---
description: At checkpoint 2 the companion hands a read-only statistics block for the tables the change queries.
tags: [data]
max_turns: 60
timeout_seconds: 1200
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
```
