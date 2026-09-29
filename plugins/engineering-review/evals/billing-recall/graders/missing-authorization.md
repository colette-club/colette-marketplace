---
type: regex
pattern: '### F-\d+ [^\n]*(authori[sz]|admin|permission|access|any(one| caller| user))'
flags: i
target: { source: file, path: '.reviews/billing.md' }
---
