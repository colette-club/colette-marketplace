---
description: "Asked in plain words to use superpowers:writing-plans, Claude calls it unmarked; the hook denies it and colette:writing-plans plans the next increment."
tags: [spec]
max_turns: 60
timeout_seconds: 1500
allowed_tools: [Read, Glob, Grep, Skill, Write]
plugins: ["../..", "deps/engineering-review", "deps/superpowers"]
---

Use the superpowers:writing-plans skill to plan the next increment of docs/superpowers/specs/2026-10-19-archive-wishes-design.md. PR #8 (Increment 1) is merged. You may read this repository without asking. I approve the plan you write; save it to docs/superpowers/plans/2026-10-19-archive-wishes-next-increment.md and stop once it is written: do not execute it.
