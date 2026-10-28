defmodule App.Communities.Activity do
  @moduledoc """
  An activity members register to. An online one is held in a live room. Its
  host is its organizer, or its creator when it has no organizer.
  """
  use App.Schema, :schema

  schema "activities" do
    field :title, :string
    field :starts_at, :utc_datetime
    field :ends_at, :utc_datetime
    field :archived_at, :utc_datetime_usec

    belongs_to :organizer, App.Accounts.User
    belongs_to :creator, App.Accounts.User

    timestamps(type: :utc_datetime_usec)
  end

  def changeset(%__MODULE__{} = activity, attrs) do
    activity
    |> cast(attrs, [:title, :starts_at, :ends_at, :organizer_id, :creator_id])
    |> validate_required([:title, :starts_at, :ends_at, :creator_id])
  end
end
