---
description: "Every skill covering the change's language and libraries is loaded and applied rule by rule; skills for things the change does not touch are not loaded."
tags: [recall]
max_turns: 80
timeout_seconds: 1500
allowed_tools: [Read, Glob, Grep, Skill, Bash, Write]
plugins: ["../..", "team-stack"]
---

/engineering-review:review-companion feature

```review-answers
target: feature
base: main
role: reviewer
exclusions: confirmed
permissions: { run_tests: no, explain_local_db: no, fetch_history: no }
compare_previous_report: no
intent: "Adds a weekly digest email: App.Digests.schedule/1 enqueues App.Workers.SendDigest, which builds and sends the digest."
necessity: "One change; it matches the ticket."
outside_context: none
runtime: ["schedule/1 is called by a weekly cron for every member", "a member can be deleted between scheduling and sending"]
effects: intended
production_stats: unknown
```
