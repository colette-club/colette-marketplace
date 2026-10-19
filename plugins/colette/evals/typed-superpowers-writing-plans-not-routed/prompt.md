---
description: "A typed /superpowers:writing-plans is not redirected: plain superpowers plans, and colette:writing-plans never runs."
tags: [spec]
max_turns: 60
timeout_seconds: 1500
allowed_tools: [Read, Glob, Grep, Skill, Write]
plugins: ["../..", "deps/engineering-review", "deps/superpowers"]
---

/superpowers:writing-plans docs/superpowers/specs/2026-10-19-archive-wishes-design.md

PR #8 (Increment 1) is merged. You may read this repository without asking. I approve the plan you write; save it to docs/superpowers/plans/2026-10-19-archive-wishes-plain-plan.md and stop once it is written: do not execute it.
