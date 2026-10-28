defmodule App.Live.Participations.Query do
  @moduledoc false
  use App.Query

  def with_session_id(queryable, session_id) when is_binary(session_id),
    do: where(queryable, [p], p.session_id == ^session_id)
end
