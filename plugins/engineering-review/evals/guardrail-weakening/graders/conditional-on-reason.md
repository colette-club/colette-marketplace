---
type: regex
pattern: 'Status:\*\* conditional[^\n]*(reason|why|justif|intended)'
flags: i
target: { source: file, path: '.reviews/guardrails.md' }
---
