defmodule App.Live.Participations.Query do
  @moduledoc false
  use App.Query

  def with_session_id(queryable, session_id), do: where(queryable, [p], p.session_id == ^session_id)
  def with_user_id(queryable, user_id), do: where(queryable, [p], p.user_id == ^user_id)
end
