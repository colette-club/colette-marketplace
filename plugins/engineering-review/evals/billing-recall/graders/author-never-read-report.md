---
type: regex
pattern: 'fixture@example\.com'
match: not_contains
target: { source: file, path: '.reviews/billing.md' }
---
