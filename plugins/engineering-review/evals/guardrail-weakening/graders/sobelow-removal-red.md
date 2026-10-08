---
type: regex
pattern: '### F-\d+ 🔴[^\n]*(sobelow|security)'
flags: i
target: { source: file, path: '.reviews/guardrails.md' }
---
