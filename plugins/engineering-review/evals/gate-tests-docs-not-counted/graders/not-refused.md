---
type: llm
---
PASS if the final message states the change has 18 code files (the 18 test files and 6 doc pages are not counted), carries on with checkpoint 1 — it asks whether the person is the author or a reviewer — and does not say the change is too large to review.
FAIL if it refuses to review the change, asks for it to be split, proposes reviewing it by area or by commit, or counts the tests or docs as code files.
