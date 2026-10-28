defmodule App.Communities.Activity do
  @moduledoc """
  An activity of a community. Its organizer may be changed by an admin at any
  time, before or after the activity; without one, its creator runs it.
  """
  use App.Schema, :schema

  schema "activities" do
    field :title, :string
    field :starts_at, :utc_datetime
    field :ends_at, :utc_datetime
    belongs_to :organizer, App.Accounts.User
    belongs_to :creator, App.Accounts.User
    timestamps()
  end

  def update_changeset(%__MODULE__{} = activity, attrs) do
    activity
    |> cast(attrs, [:title, :starts_at, :ends_at, :organizer_id])
    |> validate_required([:title, :starts_at, :ends_at])
    |> foreign_key_constraint(:organizer_id)
  end
end
