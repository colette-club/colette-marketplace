---
description: "Frontend work is checked against every frontend and framework skill, rule by rule, and the report shows which skill was applied to which files."
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
intent: "Adds a WishList component that shows a member's wishes and lets them archive one."
necessity: "One change; it matches the ticket."
outside_context: none
runtime: ["WishList renders on the member's home page"]
effects: intended
production_stats: unknown
docs_location: docs/
writes: { report: approve, memory: decline, gitignore: decline }
report_path: .reviews/frontend.md
```
