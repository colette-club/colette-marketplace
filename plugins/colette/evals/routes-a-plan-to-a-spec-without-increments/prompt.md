---
description: "A redirected plan with no spec path, where the latest spec has no Increments: colette:writing-plans names that spec and proposes increments before any plan."
tags: [spec]
max_turns: 60
timeout_seconds: 1500
allowed_tools: [Read, Glob, Grep, Skill, Write]
plugins: ["../..", "deps/engineering-review", "deps/superpowers"]
---

Use the superpowers:writing-plans skill to plan the work in our latest spec.

You may read this repository without asking.
