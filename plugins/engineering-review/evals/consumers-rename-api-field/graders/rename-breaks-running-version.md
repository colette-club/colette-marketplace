---
type: llm
---
PASS if a finding says renaming the `title` column breaks the previous version while the rolling deploy runs (it still reads and writes `title` after the migration), and recommends adding the new column and moving to it in steps instead of renaming it in one deploy.
FAIL if no finding says so.
