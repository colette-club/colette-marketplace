defmodule App.Accounts.User do
  @moduledoc "A member account."
  use App.Schema, :schema

  schema "users" do
    field :email, :string
    field :first_name, :string
    timestamps(type: :utc_datetime_usec)
  end
end
