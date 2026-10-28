defmodule App.Accounts.User do
  @moduledoc "A member account."
  use App.Schema, :schema

  schema "users" do
    field :email, :string
    field :name, :string
    timestamps()
  end

  def changeset(%__MODULE__{} = user, attrs) do
    user
    |> cast(attrs, [:email, :name])
    |> validate_required([:email])
    |> unique_constraint(:email)
  end
end
