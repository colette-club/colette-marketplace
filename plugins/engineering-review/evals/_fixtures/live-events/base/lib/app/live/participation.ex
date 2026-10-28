defmodule App.Live.Participation do
  @moduledoc "A viewer's first connection to a run of an activity's live, once per run."
  use App.Schema, :schema

  schema "live_participations" do
    field :first_joined_at, :utc_datetime_usec
    belongs_to :activity, App.Communities.Activity
    belongs_to :session, App.Live.Session
    belongs_to :user, App.Accounts.User
    timestamps(type: :utc_datetime_usec)
  end

  def create_changeset(attrs) do
    %__MODULE__{}
    |> cast(attrs, [:activity_id, :session_id, :user_id, :first_joined_at])
    |> validate_required([:activity_id, :session_id, :user_id, :first_joined_at])
    |> foreign_key_constraint(:user_id)
    |> unique_constraint([:session_id, :user_id])
  end
end
