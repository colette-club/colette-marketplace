defmodule App.Live.Participation do
  @moduledoc "A person's first connection to an activity's live room, once per person and room."
  use App.Schema, :schema

  schema "live_participations" do
    field :first_joined_at, :utc_datetime_usec
    belongs_to :session, App.Live.Session
    belongs_to :user, App.Accounts.User
    timestamps(type: :utc_datetime_usec)
  end

  def create_changeset(attrs) do
    %__MODULE__{}
    |> cast(attrs, [:session_id, :user_id, :first_joined_at])
    |> validate_required([:session_id, :user_id, :first_joined_at])
    |> unique_constraint([:session_id, :user_id])
  end
end
