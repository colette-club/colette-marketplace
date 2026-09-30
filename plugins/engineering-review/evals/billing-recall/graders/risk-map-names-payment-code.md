---
type: regex
pattern: '## 8\. Risk and attention map(?:(?!\n## )[\s\S])*(charges|providers)'
target: { source: file, path: '.reviews/billing.md' }
---
