---
description: Recall for code shipped for the next change (columns only written, an event nobody consumes, a state nothing writes), an edited migration, and rows whose meaning changes under an existing count.
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
intent: "First of three pull requests that replace an online activity's meeting link with a live room. This one records who connected: each person's role, host or viewer, so the host's connection confirms their attendance like a viewer's. It also stamps the host's presence, announces each new run, and ignores connections to an ended run: the next pull request (start, end and close a live) reads these, so it needs no migration and no new event."
necessity: "One feature, as small as it can be. Everything the next pull request needs is created here, whole, so it needs no migration."
outside_context: "Main deploys to production on every merge; staging runs every pushed branch. The next two pull requests of the series are stacked on this branch."
runtime: unknown
effects: "Confirming the attendance of whoever connects, the host included, is intended. Nothing outside this repository reacts to live events."
production_stats: unknown
```
