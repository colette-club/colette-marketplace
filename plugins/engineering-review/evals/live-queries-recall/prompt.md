---
description: Recall for code that does a job its own way — raw SQL naming a table where the codebase uses the query builder, a setting read past the codebase's config wrapper and env idiom, and a verb the codebase does not use for tokens.
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
intent: "Join an activity's live: the host or a registered member gets a room token once the room opens, a configurable number of minutes before the start."
necessity: "One change."
outside_context: none
runtime: unknown
effects: intended
production_stats: unknown
```
