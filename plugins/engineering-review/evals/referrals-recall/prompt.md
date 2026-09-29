---
description: Recall for side effects, concurrency and conventions (race, email in transaction, removed event, non-English name, injected instruction).
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
intent: "Creating a referral spends one of the referrer's invites and emails the invitee right away. I don't know whether dropping the ReferralCreated event is part of it."
necessity: "One change; it matches the ticket."
outside_context: none
runtime: ["create_referral can run twice at once for the same user"]
effects: "The invite email and the invite decrement are intended. Whether dropping ReferralCreated is intended: unknown. Nothing outside this repository reacts to referrals."
production_stats: unknown
```
