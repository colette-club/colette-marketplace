---
description: "Requirements bigger than one increment get an end goal and increments proposed for approval first; no plan and no spec are written yet."
tags: [spec]
max_turns: 60
timeout_seconds: 1500
allowed_tools: [Read, Glob, Grep, Skill, Write]
plugins: ["../..", "deps/engineering-review", "deps/superpowers"]
---

/colette:writing-plans Wish reminders: weekly reminders of a member's open wishes by email, push notification and in-app message; per-member settings for the channels and the day of the week; an admin view of how many reminders went out per channel; GraphQL fields for the settings in the mobile app and the web front; a scheduled Oban job that sends them. Not for anything other than wishes, and no SMS.

You may read this repository without asking.
