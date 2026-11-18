---
description: "The base revision's Skills table decides: a row the change deletes still applies, a listed skill that is not installed is reported not applied with its Install command, a row whose When does not fit is not loaded, and a listed skill the change edits is applied from the base."
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
intent: "Adds App.Payouts.split/2, which splits a payout total evenly between an activity's hosts."
necessity: "One change; it matches the ticket."
outside_context: none
runtime: ["split/2 is called when an activity's payouts are computed"]
effects: intended
production_stats: unknown
writes: { report: approve, memory: decline, gitignore: decline }
report_path: .reviews/skills-table.md
```
