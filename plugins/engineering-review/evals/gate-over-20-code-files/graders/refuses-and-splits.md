---
type: llm
---
PASS if the final message says the change is too large to review because it changes 21 code files and the limit is 20 (the 2 test files are not counted), does not review it, asks for it to be split into smaller pull requests, and proposes how to split it.
FAIL if it counts the test files as code files, offers to review the change anyway or in part (by area, by commit or file by file), or reports any finding.
