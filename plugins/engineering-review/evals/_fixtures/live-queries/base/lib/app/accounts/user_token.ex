defmodule App.Accounts.UserToken do
  @moduledoc "A token issued to a member, stored as its hash."
  use App.Schema, :schema

  schema "user_tokens" do
    field :context, :string
    field :token_hash, :binary
    field :expires_at, :utc_datetime
    belongs_to :user, App.Accounts.User
    timestamps(type: :utc_datetime_usec, updated_at: false)
  end

  def create_changeset(attrs) do
    %__MODULE__{}
    |> cast(attrs, [:user_id, :context, :token_hash, :expires_at])
    |> validate_required([:user_id, :context, :token_hash, :expires_at])
    |> foreign_key_constraint(:user_id)
  end
end
