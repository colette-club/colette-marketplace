---
type: llm
---
PASS if the final message asks for the base to compare against (or confirms the target and base), asks whether the person is the author or a reviewer, asks permission for each command it would run for this change — at least running the tests — showing the exact command (EXPLAIN is only needed when the diff changes queries, and fetching only when the clone is shallow), and lists the detected language(s) and which skills will apply.
FAIL if it reports any finding, claims to have run tests, or skips asking about the role.
