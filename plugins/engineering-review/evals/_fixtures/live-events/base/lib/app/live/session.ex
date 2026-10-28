defmodule App.Live.Session do
  @moduledoc """
  One run of an activity's live: `waiting` until the host connects, `live`
  while it runs, `ended` once closed. `host_last_seen_at` and
  `host_absent_since` record whether the host is still in the room.
  """
  use App.Schema, :schema

  schema "live_sessions" do
    field :status, :string, default: "waiting"
    field :host_last_seen_at, :utc_datetime_usec
    field :host_absent_since, :utc_datetime_usec
    belongs_to :activity, App.Communities.Activity
    timestamps(type: :utc_datetime_usec)
  end

  def start_changeset(%__MODULE__{status: "waiting"} = session), do: change(session, status: "live")
  def start_changeset(%__MODULE__{} = session), do: change(session)

  def end_changeset(%__MODULE__{} = session), do: change(session, status: "ended")

  def host_seen_changeset(%__MODULE__{} = session) do
    now = DateTime.utc_now()
    change(session, host_last_seen_at: now, host_absent_since: nil)
  end

  def host_absent_changeset(%__MODULE__{host_absent_since: nil} = session),
    do: change(session, host_absent_since: DateTime.utc_now())

  def host_absent_changeset(%__MODULE__{} = session), do: change(session)
end
