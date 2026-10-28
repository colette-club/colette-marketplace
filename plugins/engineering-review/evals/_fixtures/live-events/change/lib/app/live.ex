defmodule App.Live do
  @moduledoc "The live of an online activity: its runs, who joined them, and the media server."

  alias App.Live.{Host, MediaServer, Participations, Sessions}

  ## Sessions

  defdelegate get_session(activity_id), to: Sessions
  defdelegate list_running_sessions(), to: Sessions
  defdelegate list_overrun_sessions(now, minutes), to: Sessions
  defdelegate start_live(session), to: Sessions
  defdelegate end_live(session), to: Sessions
  defdelegate mark_host_seen(session, opts \\ []), to: Sessions
  defdelegate mark_host_absent(session), to: Sessions

  ## Host

  defdelegate host_id(activity), to: Host, as: :id

  ## Participations

  defdelegate record_participation(session, user_id, opts \\ []), to: Participations

  ## Media server

  defdelegate participant_in_room?(activity_id, user_id), to: MediaServer
  defdelegate verify_webhook(token, body), to: MediaServer
end
