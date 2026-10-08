---
type: regex
pattern: '### F-\d+ [^\n]*(credo|lint|nesting)'
flags: i
target: { source: file, path: '.reviews/guardrails.md' }
---
