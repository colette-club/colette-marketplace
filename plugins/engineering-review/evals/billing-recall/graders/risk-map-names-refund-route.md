---
type: regex
pattern: '## 9\. Risk and attention map(?:(?!\n## )[\s\S])*(routes\.py|refund)'
target: { source: file, path: '.reviews/billing.md' }
---
