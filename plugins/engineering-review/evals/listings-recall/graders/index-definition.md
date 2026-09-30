---
type: regex
pattern: 'create(_if_not_exists)?\s+index\(:listings,\s*\[:city_id,[^\]]*inserted_at|CREATE\s+INDEX[^;]{0,200}?ON\s+listings\s*\(\s*city_id,[^)]*inserted_at'
flags: i
target: { source: file, path: '.reviews/listings.md' }
---
