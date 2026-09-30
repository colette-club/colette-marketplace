---
type: regex
pattern: '### F-\d+ 🔴[^\n]*(secret|signing|signature|credential|key)'
flags: i
target: { source: file, path: '.reviews/billing.md' }
---
