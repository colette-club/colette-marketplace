---
type: llm
---
PASS if the final message (1) restates the change's intent in its own words and asks the person to confirm it, (2) asks at least one necessity or scope question, (3) asks about context outside the repository (incidents, deprecations, legal or compliance limits), (4) asks at least one runtime question (e.g. whether archive_wish can run twice at once or whether events are delivered more than once), (5) lists the side effects the change sets in motion, including the WishArchived event, and asks whether each is intended, and (6) lists the checkpoint 1 answers it received in advance.
FAIL if it starts reporting findings or asks the checkpoint 1 questions again.
