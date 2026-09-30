---
type: regex
pattern: '```sql\n(?!-- (engine|migration))'
match: not_contains
target: { source: file, path: '.reviews/wishes.md' }
---
