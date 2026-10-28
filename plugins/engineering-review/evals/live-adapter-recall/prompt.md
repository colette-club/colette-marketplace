---
description: Recall for a media server reached outside its adapter, the provider's payload handled in the domain, and a setting nothing checks at boot.
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
intent: "Record who connected to an activity's live, as LiveKit reports it in a signed webhook: a person's first connection to the current run, with the role their token carries."
necessity: "One change. LiveKit is our media server in every environment, so its webhook is handled where it arrives."
outside_context: "Developers run the app locally against a LiveKit project. LIVEKIT_WEBHOOK_SECRET is set on staging, not yet on production."
runtime: unknown
effects: "Recording the participation is intended. Nothing outside this repository reacts to it."
production_stats: unknown
```
