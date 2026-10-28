defmodule App.Live.Session do
  @moduledoc """
  One run of an activity's live. `status` moves waiting → live → ended.
  `activity_starts_at` is the activity's start when the run opened, stored as
  a `timestamp` without time zone holding UTC.
  """
  use App.Schema, :schema

  schema "live_sessions" do
    field :status, :string, default: "waiting"
    field :activity_starts_at, :naive_datetime
    belongs_to :activity, App.Communities.Activity
    timestamps(type: :utc_datetime_usec)
  end

  def open_changeset(attrs) do
    %__MODULE__{}
    |> cast(attrs, [:activity_id, :activity_starts_at])
    |> validate_required([:activity_id, :activity_starts_at])
  end

  def status_changeset(%__MODULE__{} = session, status) when status in ["live", "ended"],
    do: change(session, status: status)
end
