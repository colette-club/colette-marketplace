defmodule App.Live.Session do
  @moduledoc "One run of an activity's live room."
  use App.Schema, :schema

  alias App.Communities.Activity

  schema "live_sessions" do
    field :status, :string, default: "waiting"
    belongs_to :activity, Activity
    timestamps(type: :utc_datetime_usec)
  end

  def create_changeset(attrs) do
    %__MODULE__{}
    |> cast(attrs, [:activity_id])
    |> validate_required([:activity_id])
    |> foreign_key_constraint(:activity_id)
  end
end
