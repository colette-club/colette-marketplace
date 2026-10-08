---
description: "A change that weakens guardrails with no stated reason — an inline Credo disable, a new Dialyzer ignore entry, Sobelow dropped from precommit — gets EP-I3 findings, the security one red, each conditional on the missing reason."
tags: [recall, elixir]
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
permissions: { run_tests: no, run_checks: no, explain_local_db: no, fetch_history: no }
compare_previous_report: no
intent: "Lets support staff refund part of a payment."
necessity: "One change; it matches the ticket."
outside_context: none
runtime: ["partial_refund is called from the support dashboard, once per click"]
effects: intended
production_stats: unknown
writes: { report: approve, memory: decline, gitignore: decline }
report_path: .reviews/guardrails.md
```
