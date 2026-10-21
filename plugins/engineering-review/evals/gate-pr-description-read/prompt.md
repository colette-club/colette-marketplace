---
description: "With a GitHub PR known and every other checkpoint 1 question answered, checkpoint 1 still asks to read the PR's title and description with the exact gh command, and runs nothing."
tags: [gate]
max_turns: 40
timeout_seconds: 900
allowed_tools: [Read, Glob, Grep, Skill, Bash, Write]
---

/engineering-review:review-companion feature

```review-answers
target: feature
base: main
pr: 42
role: reviewer
exclusions: confirmed
permissions: { run_tests: no, explain_local_db: no, fetch_history: no }
compare_previous_report: no
```
