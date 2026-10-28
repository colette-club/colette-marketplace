defmodule App.Live.Window do
  @moduledoc "When an activity's live room opens: 15 minutes before the activity's start."

  alias App.Communities.Activity

  @opens_before_seconds 15 * 60

  @doc "Whether the activity's live room is open at `now`."
  @spec open?(Activity.t(), DateTime.t()) :: boolean()
  def open?(%Activity{starts_at: starts_at}, %DateTime{} = now) do
    opens_at = DateTime.add(starts_at, -@opens_before_seconds, :second)
    not DateTime.before?(now, opens_at)
  end
end
