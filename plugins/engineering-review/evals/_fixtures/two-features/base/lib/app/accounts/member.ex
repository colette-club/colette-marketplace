defmodule App.Accounts.Member do
  @moduledoc "A club member."
  use App.Schema, :schema

  schema "members" do
    field :email, :string
    timestamps()
  end
end
