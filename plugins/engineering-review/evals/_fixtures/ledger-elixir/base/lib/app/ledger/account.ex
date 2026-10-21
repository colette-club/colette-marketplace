defmodule App.Ledger.Account do
  @moduledoc "A member's account and its balance in cents."
  use Ecto.Schema

  schema "accounts" do
    field :balance_cents, :integer, default: 0
    timestamps()
  end
end
