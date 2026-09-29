---
type: regex
pattern: '### F-\d+ 🔴[^\n]*(secret|signing)'
flags: i
target: { source: file, path: '.reviews/billing.md' }
---
