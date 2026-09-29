---
type: regex
pattern: 'create(_if_not_exists)?\s+index\(:listings,\s*\[:city_id,[^\]]*inserted_at|CREATE\s+INDEX[^\n]*ON\s+listings\s*\(\s*city_id,[^)\n]*inserted_at'
flags: i
target: { source: file, path: '.reviews/listings.md' }
---
