---
description: "With main checked out, the companion reviews `feature` through git without switching branches or touching the working tree."
tags: [gate]
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
intent: "Creating a referral spends one of the referrer's invites and emails the invitee right away."
necessity: "One change; it matches the ticket."
outside_context: none
runtime: ["create_referral can run twice at once for the same user"]
effects: intended
production_stats: unknown
```
