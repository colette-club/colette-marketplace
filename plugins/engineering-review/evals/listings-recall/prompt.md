---
description: Recall for the data-access pass (missing composite/partial index, unindexed foreign key, N+1, unbounded list, blocking index build).
tags: [recall, data]
max_turns: 90
timeout_seconds: 1800
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
intent: "Adds a city search for active listings, newest first, with their host; adds an index on listings.host_id."
necessity: "One change; it matches the ticket."
outside_context: none
runtime: ["Listings.search/2 runs on every request of the city page, about 50,000 times a day"]
effects: intended
production_stats: "listings: n_live_tup 2300000, seq_scan 41000, idx_scan 0 (no index on city_id); cities: n_live_tup 1200"
docs_location: docs/
writes: { report: approve, memory: decline, gitignore: decline }
report_path: .reviews/listings.md
```
