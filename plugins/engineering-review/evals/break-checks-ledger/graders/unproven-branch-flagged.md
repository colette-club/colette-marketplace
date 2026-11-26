---
type: regex
pattern: '### F-\d+ 🟡(?:(?!\n### |\n## \d+\. )[\s\S])*?(?:no break proves|no row)(?:(?!\n### |\n## \d+\. )[\s\S])*?already_archived|### F-\d+ 🟡(?:(?!\n### |\n## \d+\. )[\s\S])*?already_archived(?:(?!\n### |\n## \d+\. )[\s\S])*?(?:no break proves|no row)'
flags: i
target: { source: file, path: '.reviews/break-checks.md' }
---
