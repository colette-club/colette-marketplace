---
type: regex
pattern: '### F-\d+ (?:(?!(?:(?!\n### |\n## \d+\. )[\s\S])*\*\*What\.\*\*)|(?!(?:(?!\n### |\n## \d+\. )[\s\S])*\*\*Why it matters\.\*\*)|(?!(?:(?!\n### |\n## \d+\. )[\s\S])*\*\*Evidence\.\*\*)|(?!(?:(?!\n### |\n## \d+\. )[\s\S])*\*\*Recommendation\.\*\*)|(?!(?:(?!\n### |\n## \d+\. )[\s\S])*\*\*Effort:\*\*)|(?!(?:(?!\n### |\n## \d+\. )[\s\S])*\*\*Status:\*\*))'
match: not_contains
target: { source: file, path: '.reviews/frontend.md' }
---
