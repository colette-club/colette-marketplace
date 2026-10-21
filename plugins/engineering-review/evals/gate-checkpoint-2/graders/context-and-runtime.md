---
type: llm
---
PASS if the final message asks about context outside the repository (for example incidents, deprecations, legal, compliance or retention limits, migrations in progress) and does not ask whether code can run twice at once, whether a job is retried, or whether an event is delivered more than once.
FAIL if the context question is missing, or if it asks any of those three.
