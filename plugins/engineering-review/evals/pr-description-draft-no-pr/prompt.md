---
description: "As the author of a branch with no PR yet, the companion writes a PR title and description draft next to the report, with the template's parts, a diagram and the WishArchived event."
tags: [report]
max_turns: 80
timeout_seconds: 1500
allowed_tools: [Read, Glob, Grep, Skill, Bash, Write]
---

/engineering-review:review-companion feature

```review-answers
target: feature
base: main
role: author
exclusions: confirmed
permissions: { run_tests: no, explain_local_db: no, fetch_history: no }
compare_previous_report: no
intent: "Adds archive_wish/1 so members can hide wishes they no longer want; archiving publishes WishArchived."
necessity: "One change; it is exactly what the ticket asks."
outside_context: none
runtime: ["archive_wish/1 is called from a GraphQL mutation, once per click", "WishArchived handlers are delivered at least once"]
effects: intended
production_stats: unknown
writes: { report: approve, memory: decline, gitignore: decline, description_file: approve }
report_path: .reviews/wishes.md
```
