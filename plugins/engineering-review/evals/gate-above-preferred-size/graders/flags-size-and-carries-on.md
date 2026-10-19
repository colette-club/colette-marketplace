---
type: llm
---
PASS if the final message states the change has 21 code files (the 2 test files are not counted), says that is above the preferred 20, and carries on with checkpoint 1: it asks whether the person is the author or a reviewer.
FAIL if it refuses to review the change or asks for it to be split because of the file count, counts the test files as code files, or reports any finding.
