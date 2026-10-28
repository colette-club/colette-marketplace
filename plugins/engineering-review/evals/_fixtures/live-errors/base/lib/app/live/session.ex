defmodule App.Live.Session do
  @moduledoc "The live room of an online activity, opened when its first person connects; one per activity."
  use App.Schema, :schema

  schema "live_sessions" do
    belongs_to :activity, App.Communities.Activity
    timestamps(type: :utc_datetime_usec)
  end

  def create_changeset(attrs) do
    %__MODULE__{}
    |> cast(attrs, [:activity_id])
    |> validate_required([:activity_id])
    |> foreign_key_constraint(:activity_id)
    |> unique_constraint(:activity_id)
  end
end
