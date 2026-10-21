---
type: regex
pattern: '## 9\. Risk and attention map(?:(?!\n## )[\s\S])*(charges|providers)'
target: { source: file, path: '.reviews/billing.md' }
---
