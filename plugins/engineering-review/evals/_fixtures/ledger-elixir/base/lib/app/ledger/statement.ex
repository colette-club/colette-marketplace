defmodule App.Ledger.Statement do
  @moduledoc "A monthly statement and the number of ledger entries recorded on it."
  use Ecto.Schema

  schema "statements" do
    field :month, :date
    field :entry_count, :integer, default: 0
    timestamps()
  end
end
