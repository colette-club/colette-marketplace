defmodule App.Live do
  @moduledoc "The live room of an online activity and the media server that runs it."

  alias App.Live.{MediaServer, Sessions}

  ## Sessions

  defdelegate get_session(activity_id), to: Sessions
  defdelegate get_or_create_session(activity_id), to: Sessions

  ## Media server

  defdelegate verify_webhook(token, body), to: MediaServer
end
