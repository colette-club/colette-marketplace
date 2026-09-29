---
description: With checkpoint 1 answered in advance the companion stops at checkpoint 2.
tags: [gate]
max_turns: 40
timeout_seconds: 900
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
