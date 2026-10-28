defmodule App.Workers.CheckHostPresence do
  @moduledoc """
  Every five minutes, asks the media server whether the host of each running
  live is still in the room, and stamps their presence or their absence.
  """
  use Oban.Worker, queue: :live, max_attempts: 1, unique: [period: 240]

  alias App.Communities
  alias App.Live

  @impl true
  def perform(%Oban.Job{}) do
    Enum.each(Live.list_running_sessions(), &check/1)
  end

  defp check(%Live.Session{activity_id: activity_id} = session) do
    with {:ok, activity} <- Communities.get_activity(activity_id) do
      host_id = Live.Host.id(activity)
      stamp(session, Live.participant_in_room?(activity_id, host_id))
    end
  end

  defp stamp(session, true), do: Live.mark_host_seen(session)
  defp stamp(session, false), do: Live.mark_host_absent(session)
end
