---
type: regex
pattern: '## 8\. Risk and attention map(?:(?!\n## )[\s\S])*(routes\.py|refund)'
target: { source: file, path: '.reviews/billing.md' }
---
