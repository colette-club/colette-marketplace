---
description: Recall for tests that cannot fail — a time-zone conversion no test notices when removed, and branches every test still passes on when changed.
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
intent: "Enter an activity's live: the host or a registered member may enter once the room opens, 15 minutes before the start; the room closes once the activity is over, unless its live still waits or runs; an ended run stays the current one until the activity is moved."
necessity: "One change."
outside_context: none
runtime: unknown
effects: intended
production_stats: unknown
```
