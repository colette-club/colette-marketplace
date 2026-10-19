---
description: "A feature too large for one pull request is cut into three or more increments, each the smallest step that ships one feature."
tags: [spec]
max_turns: 60
timeout_seconds: 1500
allowed_tools: [Read, Glob, Grep, Skill, Write]
plugins: ["../..", "deps/engineering-review", "deps/superpowers"]
---

/colette:brainstorming Wish reminders.

Everything you would ask is answered here:
- Who: members, in the mobile app and the web front, through the GraphQL API; staff, in the admin.
- Why: members forget the wishes they posted, so activities that would match them go unfilled.
- What: weekly reminders of a member's open wishes, by email, push notification and in-app message; per-member settings for the channels and the day of the week; an admin view of how many reminders went out per channel; GraphQL fields for the settings in the mobile app and the web front; a scheduled job that sends them.
- Non-goals: reminders for anything other than wishes; SMS.
- How it is built: in this Elixir/Phoenix app, with Oban for the scheduled job. It is one project: cut it into increments, not into separate projects.

You may read this repository without asking. I approve the design as described above and the increments you draft for it, without a playback. Write the written design to docs/superpowers/specs/2026-10-19-wish-reminders-design.md now, and do not plan or build anything yet.
