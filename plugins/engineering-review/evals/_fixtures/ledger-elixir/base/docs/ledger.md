# Ledger

Accounts hold a member's balance in cents; it can never go below zero (a check constraint). Every movement of cents is a ledger entry recorded on a monthly statement. The data lives in PostgreSQL (`lib/app/repo.ex`).
