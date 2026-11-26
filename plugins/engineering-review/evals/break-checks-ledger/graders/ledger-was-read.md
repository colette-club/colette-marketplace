---
type: regex
pattern: 'no break check found'
flags: i
match: not_contains
target: { source: file, path: '.reviews/break-checks.md' }
---
