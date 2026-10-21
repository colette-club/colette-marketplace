---
description: "Asked to plan a spec colette did not write, Claude plans it with plain superpowers: colette never runs."
tags: [spec]
max_turns: 60
timeout_seconds: 1500
allowed_tools: [Read, Glob, Grep, Skill, Write]
plugins: ["../..", "deps/engineering-review", "deps/superpowers"]
---

Plan docs/superpowers/specs/2026-10-19-wish-reminders-design.md. You may read this repository without asking. I approve the plan you write; save it to docs/superpowers/plans/2026-10-19-wish-reminders.md and stop once it is written: do not execute it.
