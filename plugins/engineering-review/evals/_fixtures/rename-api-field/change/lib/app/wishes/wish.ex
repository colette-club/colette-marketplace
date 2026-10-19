defmodule App.Wishes.Wish do
  @moduledoc "A member's wish."
  use App.Schema, :schema

  schema "wishes" do
    field :name, :string
    belongs_to :member, App.Accounts.Member
    timestamps()
  end

  def create_changeset(attrs) do
    %__MODULE__{}
    |> cast(attrs, [:name, :member_id])
    |> validate_required([:name, :member_id])
  end
end
