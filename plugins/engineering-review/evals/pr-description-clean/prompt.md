---
description: "A PR description that meets EP-F5 — under its own headings, for a PR that is not part of a sequence — gets no EP-F5 finding."
tags: [precision]
max_turns: 80
timeout_seconds: 1500
allowed_tools: [Read, Glob, Grep, Skill, Bash, Write]
---

/engineering-review:review-companion feature

````review-answers
target: feature
base: main
pr: 42
pr_title: "Wishes: members can archive a wish"
pr_description: |
  ## Summary
  Members can archive a wish they no longer want: `App.Wishes.archive_wish/1` stamps its `archived_at`.

  ## How it works
  `archive_wish/1` builds `Wish.archive_changeset/1` and saves it with `Repo.update/2` and the `success_event: Events.WishArchived` option, so `WishArchived` is published only when the update succeeds.

  ```mermaid
  flowchart LR
    A["archive_wish/1"] --> B["Wish.archive_changeset/1"] --> C["Repo.update/2"]
    C -->|"ok"| D["WishArchived published"]
    C -->|"error"| E["changeset errors returned"]
  ```

  ## Behind the scenes
  - Async: `WishArchived` is published once the update succeeds; its handlers are delivered at least once.
  - Consumers: none. No API field changes.
  - Docs: `docs/wishes/wishes.md` checked: it says what a wish is and nothing about its lifecycle, so it needed no change.
role: reviewer
exclusions: confirmed
permissions: { run_tests: no, explain_local_db: no, fetch_history: no, read_pr: no }
compare_previous_report: no
intent: "Adds archive_wish/1 so members can hide wishes they no longer want; archiving publishes WishArchived."
necessity: "One change; it is exactly what the ticket asks."
outside_context: none
runtime: ["archive_wish/1 is called from a GraphQL mutation, once per click", "WishArchived handlers are delivered at least once"]
effects: intended
production_stats: unknown
````
