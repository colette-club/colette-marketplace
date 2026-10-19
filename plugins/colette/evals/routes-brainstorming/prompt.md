---
description: "Asked to build something without the colette command, Claude ends in colette:brainstorming: its own superpowers:brainstorming call is redirected, so the spec gets its Increments."
tags: [spec]
max_turns: 60
timeout_seconds: 1500
allowed_tools: [Read, Glob, Grep, Skill, Write]
plugins: ["../..", "deps/engineering-review", "deps/superpowers"]
---

Let's build a feature in this app: members can archive a wish they no longer want.

Everything you would ask is answered here:
- Who: members, in the mobile app and the web front, through the GraphQL API.
- Why: their wish list fills up with wishes they gave up on.
- What: an Archive action on a wish. Archived wishes leave the list; members can see them and restore them from an Archived tab.
- Non-goals: deleting wishes; archiving on a member's behalf by staff.
- How it is built: in this Elixir/Phoenix app.

You may read this repository without asking. I approve the design as described above and the increments you draft for it, without a playback. Write the written design to docs/superpowers/specs/2026-10-19-archive-wishes-design.md now, and do not plan or build anything yet.
