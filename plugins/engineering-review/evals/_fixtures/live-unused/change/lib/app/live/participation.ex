defmodule App.Live.Participation do
  @moduledoc """
  Someone who joined a run of an activity's live, once per run, with the role
  they joined it as: `host` or `viewer`.
  """
  use App.Schema, :schema

  alias App.Accounts.User
  alias App.Live.Session

  schema "live_participations" do
    field :role, :string
    field :first_joined_at, :utc_datetime_usec
    belongs_to :session, Session
    belongs_to :user, User
    timestamps(type: :utc_datetime_usec)
  end

  def create_changeset(attrs) do
    %__MODULE__{}
    |> cast(attrs, [:session_id, :user_id, :role, :first_joined_at])
    |> validate_required([:session_id, :user_id, :role, :first_joined_at])
    |> validate_inclusion(:role, ~w(host viewer))
    |> foreign_key_constraint(:user_id)
    |> unique_constraint([:session_id, :user_id])
  end
end
