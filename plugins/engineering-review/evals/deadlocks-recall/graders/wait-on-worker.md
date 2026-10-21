---
type: llm
---
PASS if a finding at checkpoint 3 says that `place_order` waits on `refresh_prices`' thread-pool workers while holding the product row locks (and its pooled connection), and that each worker needs the same product row through another connection, so the request hangs in a wait the database cannot detect.
FAIL otherwise.
