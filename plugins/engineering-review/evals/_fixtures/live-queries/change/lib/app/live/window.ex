defmodule App.Live.Window do
  @moduledoc """
  When an activity's live room opens: `opens_before_minutes` of
  `config :app, :live` before the activity's start.
  """

  alias App.Communities.Activity

  @doc "Whether the activity's live room is open at `now`."
  @spec open?(Activity.t(), DateTime.t()) :: boolean()
  def open?(%Activity{starts_at: starts_at}, %DateTime{} = now) do
    minutes =
      :app
      |> Application.fetch_env!(:live)
      |> Keyword.fetch!(:opens_before_minutes)

    opens_at = DateTime.add(starts_at, -minutes * 60, :second)
    not DateTime.before?(now, opens_at)
  end
end
