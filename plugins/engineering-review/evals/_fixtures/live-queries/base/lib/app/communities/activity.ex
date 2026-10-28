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

    belongs_to :organizer, App.Accounts.User
    belongs_to :creator, App.Accounts.User

    timestamps(type: :utc_datetime_usec)
  end
end
