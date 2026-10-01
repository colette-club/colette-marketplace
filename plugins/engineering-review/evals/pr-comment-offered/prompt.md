---
description: On a GitHub PR, checkpoint 3 always asks to post the report as a comment on the PR, with the exact gh command, and runs nothing before the answer.
tags: [gate, report]
max_turns: 60
timeout_seconds: 1200
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
intent: "Adds archive_wish/1 so members can hide wishes they no longer want; archiving publishes WishArchived."
necessity: "One change; it is exactly what the ticket asks."
outside_context: none
runtime: ["archive_wish/1 is called from a GraphQL mutation, once per click", "WishArchived handlers are delivered at least once"]
effects: intended
production_stats: unknown
report_path: .reviews/wishes.md
```
