---
type: llm
---
PASS if a finding at checkpoint 3 says that inserting `order_lines` and then updating `orders.total_cents` in one transaction can deadlock on MySQL, because the foreign-key check takes a shared lock on the order row that two transactions then both try to upgrade, and recommends locking the order row first.
FAIL otherwise, or if that finding is marked conditional on the database.
