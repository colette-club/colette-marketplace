defmodule App.Repo.Migrations.CreateLedger do
  use Ecto.Migration

  def change do
    create table(:accounts) do
      add :balance_cents, :bigint, null: false, default: 0
      timestamps()
    end

    create constraint(:accounts, :balance_cents_not_negative, check: "balance_cents >= 0")

    create table(:statements) do
      add :account_id, references(:accounts, on_delete: :restrict), null: false
      add :month, :date, null: false
      add :entry_count, :integer, null: false, default: 0
      timestamps()
    end

    create unique_index(:statements, [:account_id, :month])

    create table(:ledger_entries) do
      add :amount_cents, :bigint, null: false
      add :statement_id, references(:statements, on_delete: :restrict), null: false
      timestamps()
    end

    create index(:ledger_entries, [:statement_id])
  end
end
