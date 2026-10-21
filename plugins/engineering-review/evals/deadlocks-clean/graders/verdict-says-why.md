---
type: llm
---
PASS if the checkpoint 3 message has a "Locks and deadlocks" item that gives both `transfer/3` and `record_entry/2` as unable to deadlock, each with its reason: `transfer/3` locks both accounts in id order before writing either, and on PostgreSQL the lock that inserting an entry takes on its statement does not block the update of the statement's `entry_count`.
FAIL if the item is missing, if either path is reported as able to deadlock, or if a reason is missing.
