# Ledger

Accounts hold a member's balance in cents; it can never go below zero (a check constraint). Every movement of cents is a ledger entry recorded on a monthly statement. The data lives in PostgreSQL (`lib/app/repo.ex`).

## Moving cents

- `App.Ledger.transfer/3` moves cents from one account to another. Both accounts are locked in id order before either balance changes, then the source is debited only if it holds enough. It returns `{:error, :insufficient_funds}`, `{:error, :same_account}` or `{:error, :not_found}` without changing anything.
- `App.Ledger.record_entry/2` records an entry on a statement and adds one to the statement's `entry_count`, in one transaction. An unknown statement returns `{:error, changeset}`.
