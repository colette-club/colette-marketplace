---
type: regex
pattern: '### F-\d+ [^\n]*(dialyzer|type check)'
flags: i
target: { source: file, path: '.reviews/guardrails.md' }
---
