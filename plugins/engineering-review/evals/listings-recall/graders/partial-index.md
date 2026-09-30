---
type: regex
pattern: 'create(_if_not_exists)?\s+index\(:listings,[\s\S]{0,200}?where:\s*"archived_at IS NULL"|CREATE\s+INDEX[^;]{0,200}?ON\s+listings[^;]{0,200}?WHERE\s+archived_at\s+IS\s+NULL'
flags: i
target: { source: file, path: '.reviews/listings.md' }
---
