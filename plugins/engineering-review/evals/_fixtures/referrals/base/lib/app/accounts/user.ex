defmodule App.Accounts.User do
  @moduledoc "A member account."
  use App.Schema, :schema

  schema "users" do
    field :email, :string
    field :invites_remaining, :integer, default: 3
    timestamps()
  end

  def changeset(%__MODULE__{} = user, attrs), do: cast(user, attrs, [:email, :invites_remaining])
end
