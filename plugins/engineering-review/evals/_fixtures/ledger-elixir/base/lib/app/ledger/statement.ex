defmodule App.Ledger.Statement do
  @moduledoc "An account's monthly statement and the number of ledger entries recorded on it."
  use Ecto.Schema

  schema "statements" do
    field :month, :date
    belongs_to :account, App.Ledger.Account
    field :entry_count, :integer, default: 0
    timestamps()
  end
end
