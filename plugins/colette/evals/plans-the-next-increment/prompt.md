---
description: "Given a spec whose Increment 1 shipped, /colette:writing-plans plans Increment 2 only, through superpowers:writing-plans, ending with its PR."
tags: [spec]
max_turns: 60
timeout_seconds: 1500
allowed_tools: [Read, Glob, Grep, Skill, Write]
plugins: ["../..", "deps/engineering-review", "deps/superpowers"]
---

/colette:writing-plans docs/superpowers/specs/2026-10-19-archive-wishes-design.md

PR #8 (Increment 1) is merged. You may read this repository without asking. I approve the plan you write; save it to docs/superpowers/plans/2026-10-19-archive-wishes-next-increment.md and stop once it is written: do not execute it.
