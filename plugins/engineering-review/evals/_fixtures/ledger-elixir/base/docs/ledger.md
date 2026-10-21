# Ledger

Accounts hold a member's balance in cents; it can never go below zero (a check constraint). Ledger entries are recorded on statements: one statement per account and month. The data lives in PostgreSQL (`lib/app/repo.ex`).
