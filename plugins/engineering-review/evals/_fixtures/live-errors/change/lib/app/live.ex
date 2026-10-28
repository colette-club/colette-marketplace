defmodule App.Live do
  @moduledoc "The live room of an online activity, who connected to it, and the media server that runs it."

  alias App.Live.{MediaServer, Participations, Sessions}

  ## Sessions

  defdelegate get_session(activity_id), to: Sessions
  defdelegate get_or_create_session(activity_id), to: Sessions

  ## Participations

  defdelegate record_participation(session, user_id), to: Participations

  ## Media server

  defdelegate verify_webhook(token, body), to: MediaServer
end
