---
description: "A repository rule the change itself removes is still applied from the base, and the removal is raised with the person."
tags: [precision]
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
intent: "Adds an archive_wish mutation resolver so members can archive a wish from the app."
necessity: "One change; it matches the ticket."
outside_context: none
runtime: ["archive_wish is called from a GraphQL mutation, once per click"]
effects: intended
production_stats: unknown
```
