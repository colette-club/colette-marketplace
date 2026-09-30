---
type: regex
pattern: '## 8\. Risk and attention map(?:(?!\n## )[\s\S])*(who wrote|authorship)'
flags: i
target: { source: file, path: '.reviews/billing.md' }
---
