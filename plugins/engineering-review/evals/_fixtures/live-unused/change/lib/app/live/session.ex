defmodule App.Live.Session do
  @moduledoc "One run of an activity's live room, and when its host was last seen in it."
  use App.Schema, :schema

  alias App.Communities.Activity

  schema "live_sessions" do
    field :status, :string, default: "waiting"
    field :host_last_seen_at, :utc_datetime_usec
    field :host_absent_since, :utc_datetime_usec
    belongs_to :activity, Activity
    timestamps(type: :utc_datetime_usec)
  end

  def create_changeset(attrs) do
    %__MODULE__{}
    |> cast(attrs, [:activity_id])
    |> validate_required([:activity_id])
    |> foreign_key_constraint(:activity_id)
  end

  def host_seen_changeset(%__MODULE__{} = session),
    do: change(session, host_last_seen_at: DateTime.utc_now(), host_absent_since: nil)
end
