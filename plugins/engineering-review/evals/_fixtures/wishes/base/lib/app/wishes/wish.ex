defmodule App.Wishes.Wish do
  @moduledoc "A member's wish."
  use App.Schema, :schema

  schema "wishes" do
    field :title, :string
    field :archived_at, :utc_datetime
    belongs_to :member, App.Accounts.Member
    timestamps()
  end

  def create_changeset(attrs) do
    %__MODULE__{}
    |> cast(attrs, [:title, :member_id])
    |> validate_required([:title, :member_id])
  end
end
