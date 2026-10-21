---
type: llm
---
PASS if a finding at checkpoint 3 says that `restock` updates product rows in delivery order and can deadlock (with another `restock`, with `cancel_order` or with `place_order`), and marks it as existing before this change.
FAIL if `restock` is not reported, or is reported without saying it existed before the change.
