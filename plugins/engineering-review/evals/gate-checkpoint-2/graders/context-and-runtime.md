---
type: llm
---
PASS if the final message asks about context outside the repository (for example incidents, deprecations, legal, compliance or retention limits, migrations in progress) and asks at least one question about how the code runs (for example whether archive_wish can run twice at once, who calls it, or whether events are delivered more than once).
FAIL if either is missing.
