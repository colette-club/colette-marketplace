---
type: llm
---
PASS if a finding at checkpoint 3 says that `place_order` locks product rows in the order of the cart, so two orders holding the same products in different orders can deadlock, and the finding is not marked conditional.
FAIL otherwise.
