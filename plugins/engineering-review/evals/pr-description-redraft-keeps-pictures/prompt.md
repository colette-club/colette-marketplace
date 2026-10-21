---
description: "As the author of a frontend PR whose description already holds a picture, the redraft keeps that picture's link."
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
pr_title: "Wishes: members can archive a wish from their list"
pr_description: |
  ## What it does
  Adds a wish list where each wish has a button that archives it.

  ## Screenshots and videos
  ![Wish list with an archive button on each wish](https://github.com/user-attachments/assets/0f3c2a7e-wish-list)
role: author
exclusions: confirmed
permissions: { run_tests: no, explain_local_db: no, fetch_history: no, read_pr: no }
compare_previous_report: no
intent: "Adds a WishList component whose button archives a wish through the existing archive endpoint."
necessity: "One change; it is exactly what the ticket asks."
outside_context: none
runtime: ["archiveWish is called once per click"]
effects: intended
production_stats: unknown
````
