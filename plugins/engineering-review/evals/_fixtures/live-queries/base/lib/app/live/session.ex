defmodule App.Live.Session do
  @moduledoc "One run of an activity's live. `status` moves waiting → live → ended."
  use App.Schema, :schema

  schema "live_sessions" do
    field :status, :string, default: "waiting"
    belongs_to :activity, App.Communities.Activity
    timestamps(type: :utc_datetime_usec)
  end

  def open_changeset(attrs) do
    %__MODULE__{}
    |> cast(attrs, [:activity_id])
    |> validate_required([:activity_id])
  end

  def status_changeset(%__MODULE__{} = session, status) when status in ["live", "ended"],
    do: change(session, status: status)
end
