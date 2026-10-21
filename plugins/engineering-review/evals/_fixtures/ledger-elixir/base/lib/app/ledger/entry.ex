defmodule App.Ledger.Entry do
  @moduledoc "One movement of cents, recorded on a statement."
  use Ecto.Schema
  import Ecto.Changeset

  schema "ledger_entries" do
    field :amount_cents, :integer
    belongs_to :statement, App.Ledger.Statement
    timestamps()
  end

  def changeset(entry, attrs) do
    entry
    |> cast(attrs, [:amount_cents, :statement_id])
    |> validate_required([:amount_cents, :statement_id])
    |> foreign_key_constraint(:statement_id)
  end
end
