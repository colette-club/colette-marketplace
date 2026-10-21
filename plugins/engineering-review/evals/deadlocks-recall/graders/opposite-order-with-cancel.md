---
type: llm
---
PASS if a finding at checkpoint 3 says that `place_order` (product rows first, then the order row through the order line's foreign key or the total update) and `cancel_order` (the order row first, then product rows) take the same locks in opposite orders and can deadlock.
FAIL if no finding names `cancel_order` against `place_order`.
