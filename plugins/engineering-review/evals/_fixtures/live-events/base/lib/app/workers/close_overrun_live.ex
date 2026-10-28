defmodule App.Workers.CloseOverrunLive do
  @moduledoc """
  Ends each live whose activity is over and whose host has been away for ten
  minutes or more.
  """
  use Oban.Worker, queue: :live, max_attempts: 1, unique: [period: 240]

  alias App.Live

  @absent_minutes 10

  @impl true
  def perform(%Oban.Job{}) do
    DateTime.utc_now()
    |> Live.list_overrun_sessions(@absent_minutes)
    |> Enum.each(&Live.end_live/1)
  end
end
