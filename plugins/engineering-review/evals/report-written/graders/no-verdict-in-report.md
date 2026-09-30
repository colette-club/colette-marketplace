---
type: regex
pattern: 'LGTM|I approve|approved for merge|ship it|ready to merge|requesting changes'
flags: i
match: not_contains
target: { source: file, path: '.reviews/wishes.md' }
---
