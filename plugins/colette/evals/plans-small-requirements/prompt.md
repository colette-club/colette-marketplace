---
description: "Requirements that fit in one increment are planned directly through superpowers:writing-plans with colette's scope, even though an older spec still has unshipped increments; no spec file is written."
tags: [spec]
max_turns: 60
timeout_seconds: 1500
allowed_tools: [Read, Glob, Grep, Skill, Write]
plugins: ["../..", "deps/engineering-review", "deps/superpowers"]
---

/colette:writing-plans Members can rename a wish: add `update_wish_title/2` to `App.Wishes` and an `updateWishTitle` mutation for the mobile app and the web front.

You may read this repository without asking. I approve the plan you write; save it to docs/superpowers/plans/2026-10-19-rename-wish.md and stop once it is written: do not execute it.
