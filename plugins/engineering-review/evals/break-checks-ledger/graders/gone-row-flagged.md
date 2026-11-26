---
type: regex
pattern: '### F-\d+ 🟡(?:(?!\n### |\n## \d+\. )[\s\S])*?(?:Repo\.update!|a live wish is archived)'
target: { source: file, path: '.reviews/break-checks.md' }
---
