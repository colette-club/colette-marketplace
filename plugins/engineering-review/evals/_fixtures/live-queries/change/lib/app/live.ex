defmodule App.Live do
  @moduledoc """
  The live of an online activity: its runs, one session each, and the media
  server that hosts its room.
  """

  alias App.Live.{MediaServer, Sessions}

  ## Sessions

  defdelegate fetch_session(id), to: Sessions
  defdelegate get_session(activity_id), to: Sessions
  defdelegate open_session(activity), to: Sessions
  defdelegate start_live(session), to: Sessions
  defdelegate end_live(session), to: Sessions

  ## Media server

  defdelegate get_server_url(), to: MediaServer
  defdelegate mint_participant_token(participant), to: MediaServer
end
