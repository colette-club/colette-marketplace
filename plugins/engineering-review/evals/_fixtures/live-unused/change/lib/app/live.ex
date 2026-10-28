defmodule App.Live do
  @moduledoc "The live room of an online activity: its runs, and who took part in each."

  alias App.Live.{Participations, Sessions}

  defdelegate get_or_create_session(activity_id, opts \\ []), to: Sessions
  defdelegate mark_host_seen(session), to: Sessions

  defdelegate record_participation(session, user_id, role, opts \\ []), to: Participations
  defdelegate count_participants(session_id), to: Participations
end
