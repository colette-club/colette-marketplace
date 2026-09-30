---
description: Harness health check — scaffold builds the fixture repo and git runs in the sandbox.
tags: [harness]
runs: 1
max_turns: 6
allowed_tools: [Read, Bash]
---

Run `git log --oneline main..feature` and `git diff --stat main...feature` in the current directory, then quote both outputs exactly.
