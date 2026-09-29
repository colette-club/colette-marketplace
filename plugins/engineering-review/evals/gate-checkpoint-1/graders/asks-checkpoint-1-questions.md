---
type: llm
---
PASS if the final message asks for the base to compare against (or confirms the target and base), asks whether the person is the author or a reviewer, asks permission for each command it would run (running the tests, EXPLAIN on a local database, fetching history) showing the exact command, and lists the detected language(s) and which skills will apply.
FAIL if it reports any finding, claims to have run tests, or skips asking about the role.
