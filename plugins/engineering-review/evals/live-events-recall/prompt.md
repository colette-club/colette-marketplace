---
description: Recall for events and recorded facts (one rule implemented per actor, a fact re-derived when the job runs, a domain event on every presence stamp).
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
intent: "Confirm the host's attendance when they connect to the live, as a viewer's is confirmed."
necessity: "One change. The host keeps its own event and handler, separate from the viewer's, as the product owner decided."
outside_context: none
runtime: unknown
effects: "Confirming the host's attendance is intended. Nothing outside this repository reacts to live events."
production_stats: unknown
```
