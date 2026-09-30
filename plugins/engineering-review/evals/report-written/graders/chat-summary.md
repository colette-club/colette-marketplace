---
type: llm
---

PASS if the final message is a short summary that gives counts by severity, a line about side effects (marked ⚡) that mentions the WishArchived event, the most important findings or a statement that there are none of a given severity, the path of the report under .reviews/, and ends by saying the decision to merge belongs to the human.
FAIL if the final message approves the change, requests changes, says it is ready to merge, or omits the report path.
