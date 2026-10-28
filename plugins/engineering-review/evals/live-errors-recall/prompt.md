---
description: Recall for errors and constraints (a foreign key the code does not turn into an error makes a webhook answer 500, its failure path untested; a private getter returning nil wrapped in a success).
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
intent: "Record who connected to an activity's live from the media server's webhook: one participation per person and room; two connections of one person at once return the participation the other recorded."
necessity: "One change."
outside_context: "Room tokens stay valid for six hours after they are issued."
runtime: unknown
effects: "Recording the participation, which confirms the person's attendance, is intended. Nothing outside this repository reacts to it."
production_stats: unknown
```
