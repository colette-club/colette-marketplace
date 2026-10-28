defmodule App.Live do
  @moduledoc "The live room of an online activity: its runs, who took part, and the media server behind it."

  alias App.Live.{MediaServer, Participations, Sessions}

  defdelegate get_or_create_session(activity_id, opts \\ []), to: Sessions
  defdelegate record_participation(session, user_id, role, opts \\ []), to: Participations

  defdelegate get_server_url(), to: MediaServer
  defdelegate issue_participant_token(participant), to: MediaServer
end
