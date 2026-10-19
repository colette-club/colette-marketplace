---
type: llm
---
PASS if the final message states the change has 45 code files, says that is above the preferred 20, and carries on with checkpoint 1: it asks whether the person is the author or a reviewer.
FAIL if it refuses to review the change because of the file count, offers to review it by area or by commit, or reports any finding.
