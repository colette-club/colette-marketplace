---
type: regex
pattern: '\*\*Code files:\*\* *(2[1-9]|[3-9]\d|\d{3,})'
match: not_contains
target: { source: file, path: 'docs/superpowers/specs/2026-10-19-wish-reminders-design.md' }
---
