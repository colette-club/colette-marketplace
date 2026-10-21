---
type: regex
pattern: '## 9\. Risk and attention map(?:(?!\n## )[\s\S])*(who wrote|authorship)'
flags: i
target: { source: file, path: '.reviews/billing.md' }
---
